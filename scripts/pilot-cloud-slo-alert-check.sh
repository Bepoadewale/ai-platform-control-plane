#!/usr/bin/env bash
set -euo pipefail

# Exercises real Prometheus rule evaluation without sending alerts externally. An invalid bearer is
# deliberately bounded and produces an auditable 401 burst; availability error-budget burn remains
# calculated separately from 5xx responses.
cluster_name="${PILOT_CLUSTER_NAME:-ai-platform-control-plane-pilot}"
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
aws_region="${AWS_REGION:-us-east-1}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
actual_account="$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || { echo "Unexpected AWS account." >&2; exit 1; }
aws eks update-kubeconfig --profile "$aws_profile" --name "$cluster_name" --region "$aws_region" >/dev/null

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/ai-platform-slo.XXXXXX")"
api_pid=""; prometheus_pid=""
cleanup() {
  [[ -n "$api_pid" ]] && kill "$api_pid" 2>/dev/null || true
  [[ -n "$prometheus_pid" ]] && kill "$prometheus_pid" 2>/dev/null || true
  rm -rf "$tmp_dir"
}
trap cleanup EXIT INT TERM
kubectl -n platform-system port-forward service/control-plane 18000:8000 >"$tmp_dir/api.log" 2>&1 & api_pid=$!
kubectl -n platform-observability port-forward service/prometheus-server 19090:80 >"$tmp_dir/prometheus.log" 2>&1 & prometheus_pid=$!
for _ in {1..30}; do curl -fs http://127.0.0.1:18000/healthz >/dev/null && break; sleep 1; done
curl -fs http://127.0.0.1:18000/healthz >/dev/null

for _ in {1..8}; do
  status="$(curl -sS -o /dev/null -w '%{http_code}' -H 'Authorization: Bearer deliberately-invalid-pilot-token' http://127.0.0.1:18000/api/v1/catalog)"
  [[ "$status" == "401" ]] || { echo "Expected bounded 401 drill, got $status." >&2; exit 1; }
done

alert_name="PilotUnauthorizedRequestBurst"
firing=false
for _ in {1..45}; do
  if curl -fsS http://127.0.0.1:19090/api/v1/alerts \
    | jq -e --arg alert_name "$alert_name" '[.data.alerts[] | select(.labels.alertname == $alert_name and .state == "firing")] | length > 0' >/dev/null; then
    firing=true
    break
  fi
  sleep 2
done
[[ "$firing" == true ]] || { echo "Expected $alert_name to fire." >&2; exit 1; }

availability_query='1 - (sum(rate(platform_http_requests_total{route="/api/v1/catalog",status_code=~"5.."}[2m])) / clamp_min(sum(rate(platform_http_requests_total{route="/api/v1/catalog"}[2m])), 1))'
availability="$(curl -fsSG http://127.0.0.1:19090/api/v1/query --data-urlencode "query=$availability_query" | jq -er '.data.result[0].value[1]')"
echo "Prometheus alert/SLO drill passed: $alert_name firing; catalog two-minute availability estimate=$availability. No external alert receiver was configured."
