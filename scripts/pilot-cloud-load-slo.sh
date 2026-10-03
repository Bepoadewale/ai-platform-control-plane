#!/usr/bin/env bash
set -euo pipefail

# Bounded, authenticated availability sample for the disposable pilot. It generates no
# infrastructure changes and caps concurrency/requests so it is safe for a short cost-bounded run.
cluster_name="${PILOT_CLUSTER_NAME:-ai-platform-control-plane-pilot}"
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
aws_region="${AWS_REGION:-us-east-1}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
requests="${PILOT_LOAD_REQUESTS:-60}"
concurrency="${PILOT_LOAD_CONCURRENCY:-5}"
[[ "$requests" =~ ^[1-9][0-9]*$ && "$requests" -le 200 ]] || { echo "PILOT_LOAD_REQUESTS must be 1-200." >&2; exit 1; }
[[ "$concurrency" =~ ^[1-9][0-9]*$ && "$concurrency" -le 10 ]] || { echo "PILOT_LOAD_CONCURRENCY must be 1-10." >&2; exit 1; }

actual_account="$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || { echo "Unexpected AWS account." >&2; exit 1; }
AWS_PROFILE="$aws_profile" aws eks update-kubeconfig --name "$cluster_name" --region "$aws_region" >/dev/null

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/ai-platform-load.XXXXXX")"
token_pod="pilot-load-token-$RANDOM"
api_pid=""; prometheus_pid=""
cleanup() {
  [[ -n "$api_pid" ]] && kill "$api_pid" 2>/dev/null || true
  [[ -n "$prometheus_pid" ]] && kill "$prometheus_pid" 2>/dev/null || true
  kubectl -n platform-system delete pod "$token_pod" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  rm -rf "$tmp_dir"
}
trap cleanup EXIT INT TERM

kubectl -n platform-system run "$token_pod" --restart=Never --image=curlimages/curl:8.10.1 --command -- sh -ceu '
  curl -fsS -X POST http://keycloak:8080/realms/platform/protocol/openid-connect/token \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=ai-platform-control-plane" -d "grant_type=password" \
    -d "username=developer" -d "password=local-development-only"
' >/dev/null
kubectl -n platform-system wait --for=jsonpath='{.status.phase}'=Succeeded "pod/$token_pod" --timeout=90s >/dev/null
token="$(kubectl -n platform-system logs "$token_pod" | jq -er '.access_token')"
kubectl -n platform-system port-forward service/control-plane 18000:8000 >"$tmp_dir/api.log" 2>&1 & api_pid=$!
kubectl -n platform-observability port-forward service/prometheus-server 19090:80 >"$tmp_dir/prometheus.log" 2>&1 & prometheus_pid=$!
api_ready=false
for _ in {1..30}; do
  if curl -fs http://127.0.0.1:18000/healthz >/dev/null; then api_ready=true; break; fi
  sleep 1
done
if [[ "$api_ready" != true ]]; then
  cat "$tmp_dir/api.log" >&2
  exit 1
fi

seq 1 "$requests" | xargs -P "$concurrency" -I{} sh -c \
  'curl --fail --silent --show-error -H "Authorization: Bearer $1" http://127.0.0.1:18000/api/v1/catalog >/dev/null' _ "$token"

query='sum(increase(platform_http_requests_total{route="/api/v1/catalog",status_code=~"2.."}[2m]))'
observed="0"
for _ in {1..30}; do
  observed="$(curl -fsSG http://127.0.0.1:19090/api/v1/query --data-urlencode "query=$query" | jq -er '.data.result[0].value[1]')"
  awk -v observed="$observed" -v expected="$requests" 'BEGIN { exit !(observed >= expected) }' && break
  sleep 2
done
awk -v observed="$observed" -v expected="$requests" 'BEGIN { exit !(observed >= expected) }' || {
  echo "Prometheus observed $observed successful catalog requests; expected at least $requests." >&2; exit 1;
}
echo "Bounded cloud load/SLO sample passed: $requests authenticated catalog requests at concurrency $concurrency; Prometheus observed $observed successful requests in the two-minute window."
