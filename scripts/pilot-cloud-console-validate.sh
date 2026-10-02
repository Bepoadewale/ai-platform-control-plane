#!/usr/bin/env bash
set -euo pipefail

# Validate the cloud Console against EKS through safe local port-forwards. It does
# not expose the API or Keycloak publicly and does not create a workload request.
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cluster_name="${PILOT_CLUSTER_NAME:-ai-platform-control-plane-pilot}"
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
aws_region="${AWS_REGION:-us-east-1}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/ai-platform-cloud-console-validate.XXXXXX")"
console_pid=""
api_pid=""
keycloak_pid=""

cleanup() {
  [[ -n "$console_pid" ]] && kill "$console_pid" 2>/dev/null || true
  [[ -n "$api_pid" ]] && kill "$api_pid" 2>/dev/null || true
  [[ -n "$keycloak_pid" ]] && kill "$keycloak_pid" 2>/dev/null || true
  rm -rf "$tmp_dir"
}
trap cleanup EXIT INT TERM

for command in aws kubectl curl jq python3; do
  command -v "$command" >/dev/null 2>&1 || { echo "$command is required." >&2; exit 1; }
done
actual_account="$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || { echo "Unexpected AWS account." >&2; exit 1; }
AWS_PROFILE="$aws_profile" aws eks update-kubeconfig --name "$cluster_name" --region "$aws_region" >/dev/null

for deployment in control-plane keycloak operator-console; do
  kubectl -n platform-system get deployment "$deployment" -o jsonpath='{.status.availableReplicas}' | grep -qx '1'
done
kubectl -n platform-system port-forward service/operator-console 18083:8080 >"$tmp_dir/console.log" 2>&1 & console_pid=$!
kubectl -n platform-system port-forward service/control-plane 18000:8000 >"$tmp_dir/api.log" 2>&1 & api_pid=$!
kubectl -n platform-system port-forward service/keycloak 18081:8080 >"$tmp_dir/keycloak.log" 2>&1 & keycloak_pid=$!
for _ in {1..30}; do
  curl --fail --silent http://localhost:18083/healthz >/dev/null && \
    curl --fail --silent http://localhost:18000/healthz >/dev/null && \
    curl --fail --silent http://localhost:18081/realms/platform/.well-known/openid-configuration >/dev/null && break
  sleep 1
done
curl --fail --silent http://localhost:18083/ | grep -q 'Request capacity without receiving administrator credentials'
curl --fail --silent http://localhost:18083/runtime-config.js | grep -q 'localhost:18000'
curl --fail --silent --include --request OPTIONS \
  -H 'Origin: http://localhost:18083' -H 'Access-Control-Request-Method: GET' \
  http://localhost:18000/api/v1/catalog | grep -i 'access-control-allow-origin: http://localhost:18083' >/dev/null
CONSOLE_ISSUER=http://localhost:18081/realms/platform \
  CONSOLE_ORIGIN=http://localhost:18083 \
  CONSOLE_API_BASE_URL=http://localhost:18000 \
  "$project_root/scripts/console-browser-smoke.sh"
echo "Cloud Console validation passed: EKS-hosted UI, Keycloak PKCE login/logout, explicit CORS, and signed API request."
