#!/usr/bin/env bash
set -euo pipefail

# Configures the checked-in public HTTP Ingress after the AWS Load Balancer Controller has created
# its generated DNS name. This is deliberately a no-domain pilot: the origin is exact, never a
# wildcard, temporary tunnel, or TLS claim is involved.
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
aws_region="${AWS_REGION:-us-east-1}"
cluster_name="${PILOT_CLUSTER_NAME:-ai-platform-control-plane-pilot}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
namespace="platform-system"
ingress_name="platform-public-console"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/ai-platform-public-alb.XXXXXX")"
keycloak_forward_pid=""

cleanup() {
  [[ -n "$keycloak_forward_pid" ]] && kill "$keycloak_forward_pid" 2>/dev/null || true
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

for command in aws kubectl curl jq; do
  command -v "$command" >/dev/null 2>&1 || { echo "$command is required." >&2; exit 1; }
done

actual_account="$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || { echo "Unexpected AWS account." >&2; exit 1; }
aws eks update-kubeconfig --profile "$aws_profile" --name "$cluster_name" --region "$aws_region" >/dev/null
kubectl -n kube-system rollout status deployment/aws-load-balancer-controller --timeout=5m
kubectl apply -f "$project_root/platform/cloud/runtime/public-ingress.yaml"

hostname=""
for _ in {1..90}; do
  hostname="$(kubectl -n "$namespace" get ingress "$ingress_name" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
  [[ -n "$hostname" ]] && break
  sleep 5
done
[[ -n "$hostname" ]] || { echo "Timed out waiting for the public ALB DNS name." >&2; exit 1; }
origin="http://${hostname}"

# The ALB DNS name is created at runtime, so it cannot be committed as a fixed Keycloak redirect
# URI. Persist it in a project-owned ConfigMap and restart only the three consumers. Argo continues
# to own their images, manifests, policy, and deployment topology.
runtime_config="$tmp_dir/runtime-config.js"
printf '%s\n' \
  'window.PLATFORM_CONSOLE_CONFIG = {' \
  "  apiBaseUrl: \"${origin}\"," \
  "  issuer: \"${origin}/realms/platform\"," \
  '  clientId: "ai-platform-control-plane",' \
  '};' >"$runtime_config"
kubectl -n "$namespace" create configmap platform-public-runtime \
  --from-literal=keycloak-hostname="$origin" \
  --from-literal=jwt-issuer="$origin/realms/platform" \
  --from-literal=cors-origins="$origin" \
  --from-file=runtime-config.js="$runtime_config" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$namespace" rollout restart deployment/keycloak deployment/control-plane deployment/operator-console
kubectl -n "$namespace" rollout status deployment/keycloak --timeout=10m
kubectl -n "$namespace" rollout status deployment/control-plane --timeout=5m
kubectl -n "$namespace" rollout status deployment/operator-console --timeout=5m

# Update the public OIDC client's exact redirect, web origin, and logout redirect through the
# Keycloak admin API. No wildcard origin is accepted. This configuration lives in the pilot RDS
# realm database and is removed together with the pilot.
kubectl -n "$namespace" port-forward service/keycloak 18081:8080 >"$tmp_dir/keycloak-forward.log" 2>&1 &
keycloak_forward_pid=$!
for _ in {1..30}; do
  curl -fsS http://127.0.0.1:18081/realms/platform/.well-known/openid-configuration >/dev/null && break
  sleep 1
done
admin_user="$(kubectl -n "$namespace" get secret platform-runtime-secrets -o jsonpath='{.data.keycloak-admin-username}' | base64 --decode)"
admin_password="$(kubectl -n "$namespace" get secret platform-runtime-secrets -o jsonpath='{.data.keycloak-admin-password}' | base64 --decode)"
admin_token="$(curl -fsS -X POST http://127.0.0.1:18081/realms/master/protocol/openid-connect/token \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode grant_type=password \
  --data-urlencode client_id=admin-cli \
  --data-urlencode username="$admin_user" \
  --data-urlencode password="$admin_password" | jq -r '.access_token')"
[[ "$admin_token" != "null" && -n "$admin_token" ]] || { echo "Keycloak admin token was not issued." >&2; exit 1; }
client_uuid="$(curl -fsS http://127.0.0.1:18081/admin/realms/platform/clients?clientId=ai-platform-control-plane \
  -H "Authorization: Bearer $admin_token" | jq -r '.[0].id')"
[[ "$client_uuid" != "null" && -n "$client_uuid" ]] || { echo "Keycloak console client was not found." >&2; exit 1; }
client_payload="$(jq -n --arg origin "$origin" '{redirectUris: [$origin + "/*"], webOrigins: [$origin], attributes: {"post.logout.redirect.uris": ($origin + "/*")}}')"
curl -fsS -X PUT "http://127.0.0.1:18081/admin/realms/platform/clients/${client_uuid}" \
  -H "Authorization: Bearer $admin_token" -H 'Content-Type: application/json' --data "$client_payload" >/dev/null

for _ in {1..60}; do
  curl -fsS "$origin/healthz" | jq -e '.status == "ok"' >/dev/null && \
    curl -fsS "$origin/realms/platform/.well-known/openid-configuration" | jq -e --arg issuer "$origin/realms/platform" '.issuer == $issuer' >/dev/null && \
    curl -fsS "$origin/" | grep -q 'AI Platform' && break
  sleep 2
done
curl -fsS "$origin/healthz" | jq -e '.status == "ok"' >/dev/null
curl -fsS "$origin/realms/platform/.well-known/openid-configuration" | jq -e --arg issuer "$origin/realms/platform" '.issuer == $issuer' >/dev/null
curl -fsS "$origin/" | grep -q 'AI Platform'
echo "Public ALB HTTP origin: ${origin}"
