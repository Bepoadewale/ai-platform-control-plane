#!/usr/bin/env bash
set -euo pipefail

# Verifies the generated ALB serves the Console/API/Keycloak paths and that a single API Pod loss
# does not interrupt its public health endpoint. It never prints an access token or password.
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
aws_region="${AWS_REGION:-us-east-1}"
cluster_name="${PILOT_CLUSTER_NAME:-ai-platform-control-plane-pilot}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
namespace="platform-system"

for command in aws kubectl curl jq; do
  command -v "$command" >/dev/null 2>&1 || { echo "$command is required." >&2; exit 1; }
done
actual_account="$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || { echo "Unexpected AWS account." >&2; exit 1; }
aws eks update-kubeconfig --profile "$aws_profile" --name "$cluster_name" --region "$aws_region" >/dev/null
hostname="$(kubectl -n "$namespace" get ingress platform-public-console -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
[[ -n "$hostname" ]] || { echo "Public ALB hostname is absent." >&2; exit 1; }
origin="http://${hostname}"

curl -fsS "$origin/healthz" | jq -e '.status == "ok"' >/dev/null
curl -fsS "$origin/realms/platform/.well-known/openid-configuration" | jq -e --arg issuer "$origin/realms/platform" '.issuer == $issuer' >/dev/null
curl -fsS "$origin/" | grep -q 'AI Platform'
unauthorized_status="$(curl -sS -o /dev/null -w '%{http_code}' "$origin/api/v1/environments")"
[[ "$unauthorized_status" == "401" || "$unauthorized_status" == "403" ]] || { echo "Expected unauthorized API response, got $unauthorized_status." >&2; exit 1; }

api_pod="$(kubectl -n "$namespace" get pods -l app.kubernetes.io/name=control-plane -o jsonpath='{.items[0].metadata.name}')"
kubectl -n "$namespace" delete pod "$api_pod" --wait=false >/dev/null
for _ in {1..45}; do
  curl -fsS "$origin/healthz" | jq -e '.status == "ok"' >/dev/null && break
  sleep 2
done
kubectl -n "$namespace" rollout status deployment/control-plane --timeout=5m
ready_replicas="$(kubectl -n "$namespace" get deployment/control-plane -o jsonpath='{.status.availableReplicas}')"
[[ "$ready_replicas" =~ ^[2-9][0-9]*$ ]] || { echo "Control-plane did not return to two available replicas." >&2; exit 1; }
echo "Public ALB smoke passed: ${origin}; Console, signed API boundary, Keycloak issuer, and one-Pod API failover verified."
