#!/usr/bin/env bash
set -euo pipefail

# Starts an authenticated, short-lived Cloudflare Quick Tunnel for the EKS-hosted Operator Console.
# The only public exposure is the local proxy; no AWS ingress, DNS, or TLS resource is created.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cluster_name="${PILOT_CLUSTER_NAME:-ai-platform-control-plane-pilot}"
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
aws_region="${AWS_REGION:-us-east-1}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
proxy_port="${PILOT_TUNNEL_PROXY_PORT:-18090}"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/ai-platform-console-tunnel.XXXXXX")"
console_pid=""; api_pid=""; keycloak_pid=""; proxy_pid=""; tunnel_pid=""
client_json="$tmp_dir/client.json"

cleanup() {
  [[ -n "$tunnel_pid" ]] && kill "$tunnel_pid" 2>/dev/null || true
  [[ -n "$proxy_pid" ]] && kill "$proxy_pid" 2>/dev/null || true
  [[ -n "$console_pid" ]] && kill "$console_pid" 2>/dev/null || true
  [[ -n "$api_pid" ]] && kill "$api_pid" 2>/dev/null || true
  [[ -n "$keycloak_pid" ]] && kill "$keycloak_pid" 2>/dev/null || true
  if [[ -s "$client_json" && -n "${admin_token:-}" && -n "${client_id:-}" ]]; then
    curl --silent --show-error --fail -X PUT "http://127.0.0.1:18081/admin/realms/platform/clients/$client_id" \
      -H "Authorization: Bearer $admin_token" -H 'Content-Type: application/json' --data-binary @"$client_json" >/dev/null || true
  fi
  rm -rf "$tmp_dir"
}
trap cleanup EXIT INT TERM

for command in aws kubectl curl jq python3 cloudflared; do
  command -v "$command" >/dev/null 2>&1 || { echo "$command is required." >&2; exit 1; }
done
actual_account="$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || { echo "Unexpected AWS account." >&2; exit 1; }
AWS_PROFILE="$aws_profile" aws eks update-kubeconfig --name "$cluster_name" --region "$aws_region" >/dev/null
kubectl -n platform-system get deployment control-plane -o jsonpath='{.status.availableReplicas}' | grep -Eq '^[2-9][0-9]*$'
for deployment in keycloak operator-console; do
  kubectl -n platform-system get deployment "$deployment" -o jsonpath='{.status.availableReplicas}' | grep -qx '1'
done

kubectl -n platform-system port-forward service/operator-console 18083:8080 >"$tmp_dir/console.log" 2>&1 & console_pid=$!
kubectl -n platform-system port-forward service/control-plane 18000:8000 >"$tmp_dir/api.log" 2>&1 & api_pid=$!
kubectl -n platform-system port-forward service/keycloak 18081:8080 >"$tmp_dir/keycloak.log" 2>&1 & keycloak_pid=$!
for _ in {1..30}; do
  curl --fail --silent http://127.0.0.1:18083/healthz >/dev/null && \
    curl --fail --silent http://127.0.0.1:18000/healthz >/dev/null && \
    curl --fail --silent http://127.0.0.1:18081/realms/platform/.well-known/openid-configuration >/dev/null && break
  sleep 1
done
PILOT_TUNNEL_PROXY_PORT="$proxy_port" python3 "$root/scripts/pilot_cloud_console_proxy.py" >"$tmp_dir/proxy.log" 2>&1 & proxy_pid=$!
for _ in {1..15}; do curl --fail --silent "http://127.0.0.1:$proxy_port/healthz" >/dev/null && break; sleep 1; done

cloudflared tunnel --url "http://127.0.0.1:$proxy_port" --protocol http2 >"$tmp_dir/tunnel.log" 2>&1 & tunnel_pid=$!
for _ in {1..60}; do
  public_url="$(grep -Eo 'https://[-a-z0-9]+\.trycloudflare\.com' "$tmp_dir/tunnel.log" | head -n 1 || true)"
  [[ -n "${public_url:-}" ]] && break
  sleep 1
done
[[ -n "${public_url:-}" ]] || { cat "$tmp_dir/tunnel.log" >&2; exit 1; }
printf '%s\n' "$public_url" > /tmp/ai-platform-control-plane-console-tunnel-url

admin_user="$(kubectl -n platform-system get secret platform-runtime-secrets -o jsonpath='{.data.keycloak-admin-username}' | base64 --decode)"
admin_password="$(kubectl -n platform-system get secret platform-runtime-secrets -o jsonpath='{.data.keycloak-admin-password}' | base64 --decode)"
admin_token="$(curl --fail --silent -X POST http://127.0.0.1:18081/realms/master/protocol/openid-connect/token -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode client_id=admin-cli --data-urlencode grant_type=password --data-urlencode "username=$admin_user" --data-urlencode "password=$admin_password" | jq -er '.access_token')"
client_id="$(curl --fail --silent -H "Authorization: Bearer $admin_token" 'http://127.0.0.1:18081/admin/realms/platform/clients?clientId=ai-platform-control-plane' | jq -er '.[0].id')"
curl --fail --silent -H "Authorization: Bearer $admin_token" "http://127.0.0.1:18081/admin/realms/platform/clients/$client_id" >"$client_json"
jq --arg url "$public_url" '.redirectUris += [$url + "/*"] | .webOrigins += [$url] | .redirectUris |= unique | .webOrigins |= unique' "$client_json" >"$tmp_dir/client-updated.json"
curl --fail --silent -X PUT "http://127.0.0.1:18081/admin/realms/platform/clients/$client_id" -H "Authorization: Bearer $admin_token" -H 'Content-Type: application/json' --data-binary @"$tmp_dir/client-updated.json" >/dev/null

echo "Authenticated temporary Operator Console: $public_url"
echo "Sign in with the synthetic pilot fixture. Ctrl-C stops the tunnel, local proxy, port-forwards, and restores the Keycloak client configuration."
while kill -0 "$tunnel_pid" 2>/dev/null && kill -0 "$proxy_pid" 2>/dev/null; do sleep 2; done
echo "The temporary Console tunnel ended." >&2
exit 1
