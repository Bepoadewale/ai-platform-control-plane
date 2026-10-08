#!/usr/bin/env bash
set -euo pipefail

# Opens the cloud-hosted Console through three local port-forwards. It deliberately
# creates no public load balancer, ingress, DNS record, or temporary public proxy.
cluster_name="${PILOT_CLUSTER_NAME:-ai-platform-control-plane-pilot}"
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
aws_region="${AWS_REGION:-us-east-1}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
console_port="${PILOT_CONSOLE_PORT:-18083}"
api_port="${PILOT_CONSOLE_API_PORT:-18000}"
keycloak_port="${PILOT_CONSOLE_KEYCLOAK_PORT:-18081}"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/ai-platform-cloud-console.XXXXXX")"
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

for command in aws kubectl curl; do
  command -v "$command" >/dev/null 2>&1 || { echo "$command is required." >&2; exit 1; }
done
actual_account="$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || { echo "Unexpected AWS account." >&2; exit 1; }
AWS_PROFILE="$aws_profile" aws eks update-kubeconfig --name "$cluster_name" --region "$aws_region" >/dev/null

for deployment in control-plane keycloak operator-console; do
  kubectl -n platform-system get deployment "$deployment" -o jsonpath='{.status.availableReplicas}' | grep -qx '1'
done

kubectl -n platform-system port-forward service/operator-console "${console_port}:8080" >"$tmp_dir/console.log" 2>&1 & console_pid=$!
kubectl -n platform-system port-forward service/control-plane "${api_port}:8000" >"$tmp_dir/api.log" 2>&1 & api_pid=$!
kubectl -n platform-system port-forward service/keycloak "${keycloak_port}:8080" >"$tmp_dir/keycloak.log" 2>&1 & keycloak_pid=$!
for _ in {1..30}; do
  curl --fail --silent "http://localhost:${console_port}/healthz" >/dev/null && \
    curl --fail --silent "http://localhost:${api_port}/healthz" >/dev/null && \
    curl --fail --silent "http://localhost:${keycloak_port}/realms/platform/.well-known/openid-configuration" >/dev/null && break
  sleep 1
done
curl --fail --silent "http://localhost:${console_port}/healthz" >/dev/null

echo "Cloud-backed Operator Console: http://localhost:${console_port}"
echo "This is an authenticated local port-forward to EKS; no public cloud endpoint was created. Ctrl-C stops port-forwards only."
while kill -0 "$console_pid" 2>/dev/null && kill -0 "$api_pid" 2>/dev/null && kill -0 "$keycloak_pid" 2>/dev/null; do sleep 2; done
echo "A Console port-forward ended." >&2
exit 1
