#!/usr/bin/env bash
set -euo pipefail

# Executes bounded, disposable evidence checks against the named cloud pilot.
# It never applies Terraform and never creates an environment workload: the
# successful runtime path is intentionally render-only until GitOps publishing
# and a durable reconciler are added.
cluster_name="${PILOT_CLUSTER_NAME:-ai-platform-control-plane-pilot}"
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
aws_region="${AWS_REGION:-us-east-1}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
api_port="${PILOT_VALIDATE_API_PORT:-18081}"
prometheus_port="${PILOT_VALIDATE_PROMETHEUS_PORT:-19091}"
tempo_port="${PILOT_VALIDATE_TEMPO_PORT:-13201}"
grafana_port="${PILOT_VALIDATE_GRAFANA_PORT:-13001}"
token_pod="pilot-cloud-token-$RANDOM"
api_forward_pid=""
prometheus_forward_pid=""
tempo_forward_pid=""
grafana_forward_pid=""
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/ai-platform-cloud-validate.XXXXXX")"

cleanup() {
  [[ -n "$api_forward_pid" ]] && kill "$api_forward_pid" 2>/dev/null || true
  [[ -n "$prometheus_forward_pid" ]] && kill "$prometheus_forward_pid" 2>/dev/null || true
  [[ -n "$tempo_forward_pid" ]] && kill "$tempo_forward_pid" 2>/dev/null || true
  [[ -n "$grafana_forward_pid" ]] && kill "$grafana_forward_pid" 2>/dev/null || true
  kubectl -n platform-system delete pod "$token_pod" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  rm -rf "$tmp_dir"
}
trap cleanup EXIT INT TERM

for command in aws kubectl curl jq python3; do
  command -v "$command" >/dev/null 2>&1 || { echo "$command is required." >&2; exit 1; }
done
actual_account="$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || { echo "Unexpected AWS account." >&2; exit 1; }
AWS_PROFILE="$aws_profile" aws eks update-kubeconfig --name "$cluster_name" --region "$aws_region" >/dev/null

wait_http() {
  local url="$1"
  for _ in {1..30}; do
    curl --fail --silent "$url" >/dev/null && return 0
    sleep 1
  done
  echo "Timed out waiting for $url" >&2
  return 1
}

start_api_forward() {
  [[ -n "$api_forward_pid" ]] && kill "$api_forward_pid" 2>/dev/null || true
  [[ -n "$api_forward_pid" ]] && wait "$api_forward_pid" 2>/dev/null || true
  kubectl -n platform-system port-forward service/control-plane "$api_port:8000" >"$tmp_dir/api-forward.log" 2>&1 &
  api_forward_pid=$!
  wait_http "http://127.0.0.1:$api_port/healthz"
}

kubectl -n argocd get application ai-platform-control-plane-runtime \
  -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}' | grep -qx 'Synced Healthy'
kubectl -n platform-system get deployment control-plane -o jsonpath='{.status.availableReplicas}' | grep -qx '1'
kubectl -n platform-system get deployment opa -o jsonpath='{.status.availableReplicas}' | grep -qx '1'
kubectl -n platform-observability get deployment prometheus-server -o jsonpath='{.status.availableReplicas}' | grep -qx '1'
kubectl -n platform-observability get deployment grafana -o jsonpath='{.status.availableReplicas}' | grep -qx '1'

start_api_forward

# Keycloak is internal-only. Request the pilot developer token from a temporary
# in-cluster curl pod so its issuer matches the FQDN FastAPI validates.
kubectl -n platform-system run "$token_pod" --restart=Never --image=curlimages/curl:8.10.1 \
  --command -- sh -ceu '
    curl -fsS -X POST http://keycloak:8080/realms/platform/protocol/openid-connect/token \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "client_id=ai-platform-control-plane" \
      -d "grant_type=password" \
      -d "username=developer" \
      -d "password=local-development-only"
  ' >/dev/null
kubectl -n platform-system wait --for=jsonpath='{.status.phase}'=Succeeded "pod/$token_pod" --timeout=90s >/dev/null
kubectl -n platform-system logs "$token_pod" >"$tmp_dir/token.json"
token="$(jq -er '.access_token' "$tmp_dir/token.json")"

curl --fail --silent -H "Authorization: Bearer $token" \
  "http://127.0.0.1:$api_port/api/v1/catalog" >"$tmp_dir/catalog.json"
jq -e '.environment_types | index("production")' "$tmp_dir/catalog.json" >/dev/null

request_id="$(python3 -c 'import uuid; print(uuid.uuid4())')"
jq -n --arg request_id "$request_id" '{
  request_id: $request_id,
  idempotency_key: "cloud-pilot-cross-tenant-001",
  name: "cloud-denial",
  team: "another-tenant",
  environment_type: "development",
  ttl_hours: 1,
  services: ["api"],
  image: "nginxinc/nginx-unprivileged:1.27-alpine",
  observability: true,
  workload: {size: "small", replicas: 1, privileged: false, gpu_count: 0, min_replicas: 1, max_replicas: 1, scaling_policy: "cpu"},
  cost_center: "pilot"
}' >"$tmp_dir/denial-request.json"

curl --fail --silent -X POST "http://127.0.0.1:$api_port/api/v1/environments" \
  -H "Authorization: Bearer $token" -H 'Content-Type: application/json' \
  --data-binary @"$tmp_dir/denial-request.json" >"$tmp_dir/denial.json"
jq -e '.state == "REJECTED" and (.failure_reason | contains("tenant boundary violation"))' "$tmp_dir/denial.json" >/dev/null
environment_id="$(jq -er '.id' "$tmp_dir/denial.json")"
curl --fail --silent -H "Authorization: Bearer $token" \
  "http://127.0.0.1:$api_port/api/v1/environments/$environment_id/audit-events" >"$tmp_dir/audit.json"
jq -e 'map(.action) | index("policy.rejected")' "$tmp_dir/audit.json" >/dev/null

# Restart only the API Deployment. The persisted rejected request and audit
# timeline must still be readable after the new process reconnects to RDS.
kubectl -n platform-system rollout restart deployment/control-plane >/dev/null
kubectl -n platform-system rollout status deployment/control-plane --timeout=240s >/dev/null
start_api_forward
for _ in {1..30}; do
  if curl --fail --silent -H "Authorization: Bearer $token" \
    "http://127.0.0.1:$api_port/api/v1/environments/$environment_id" >"$tmp_dir/recovered.json"; then
    break
  fi
  sleep 1
done
jq -e '.state == "REJECTED" and (.failure_reason | contains("tenant boundary violation"))' "$tmp_dir/recovered.json" >/dev/null

kubectl -n platform-observability port-forward service/prometheus-server "$prometheus_port:80" >"$tmp_dir/prometheus-forward.log" 2>&1 &
prometheus_forward_pid=$!
wait_http "http://127.0.0.1:$prometheus_port/-/ready"
for _ in {1..8}; do
  curl --fail --silent --get "http://127.0.0.1:$prometheus_port/api/v1/query" \
    --data-urlencode 'query=sum(platform_requests_total)' >"$tmp_dir/prometheus.json"
  jq -e '.data.result | length > 0' "$tmp_dir/prometheus.json" >/dev/null && break
  sleep 5
done
jq -e '.data.result | length > 0' "$tmp_dir/prometheus.json" >/dev/null
curl --fail --silent "http://127.0.0.1:$prometheus_port/api/v1/targets" >"$tmp_dir/targets.json"
jq -e '[.data.activeTargets[] | select(.labels.job == "control-plane") | select(.health == "up")] | length == 1' "$tmp_dir/targets.json" >/dev/null

kubectl -n platform-observability port-forward service/tempo "$tempo_port:3200" >"$tmp_dir/tempo-forward.log" 2>&1 &
tempo_forward_pid=$!
wait_http "http://127.0.0.1:$tempo_port/ready"
curl --fail --silent "http://127.0.0.1:$tempo_port/api/search?tags=service.name%3Dai-platform-control-plane&limit=5" >"$tmp_dir/traces.json"
jq -e '.traces | length > 0' "$tmp_dir/traces.json" >/dev/null

grafana_password="$(kubectl -n platform-observability get secret grafana -o jsonpath='{.data.admin-password}' | base64 --decode)"
kubectl -n platform-observability port-forward service/grafana "$grafana_port:80" >"$tmp_dir/grafana-forward.log" 2>&1 &
grafana_forward_pid=$!
wait_http "http://127.0.0.1:$grafana_port/api/health"
curl --fail --silent -u "admin:$grafana_password" \
  "http://127.0.0.1:$grafana_port/api/search?query=AI%20Platform%20Control%20Plane" >"$tmp_dir/grafana.json"
jq -e 'map(select(.title == "AI Platform Control Plane")) | length == 1' "$tmp_dir/grafana.json" >/dev/null

echo "Cloud pilot validation passed: signed Keycloak JWT, live OPA denial, RDS restart recovery, Argo health, Prometheus scrape, Tempo trace, and Grafana dashboard."
