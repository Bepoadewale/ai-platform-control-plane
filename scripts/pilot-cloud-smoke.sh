#!/usr/bin/env bash
set -euo pipefail

cluster_name="${PILOT_CLUSTER_NAME:-ai-platform-control-plane-pilot}"
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
aws_region="${AWS_REGION:-us-east-1}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
actual_account="$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || { echo "Unexpected AWS account." >&2; exit 1; }
AWS_PROFILE="$aws_profile" aws eks update-kubeconfig --name "$cluster_name" --region "$aws_region" >/dev/null

kubectl -n argocd get application ai-platform-control-plane-runtime \
  -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}' | grep -qx 'Synced Healthy'
kubectl -n platform-system get deployment control-plane -o jsonpath='{.status.availableReplicas}' | grep -qx '1'
kubectl -n platform-system get deployment operator-console -o jsonpath='{.status.availableReplicas}' | grep -qx '1'
kubectl -n platform-system get deployment opa -o jsonpath='{.status.availableReplicas}' | grep -qx '1'
kubectl -n platform-observability get deployment prometheus-server -o jsonpath='{.status.availableReplicas}' | grep -qx '1'
kubectl -n platform-observability get deployment grafana -o jsonpath='{.status.availableReplicas}' | grep -qx '1'

kubectl -n platform-system port-forward service/control-plane 18000:8000 >/tmp/ai-platform-control-plane-port-forward.log 2>&1 &
port_forward_pid=$!
trap 'kill "$port_forward_pid" 2>/dev/null || true' EXIT
for _ in {1..30}; do
  if curl --fail --silent http://127.0.0.1:18000/healthz >/dev/null; then break; fi
  sleep 1
done
curl --fail --silent http://127.0.0.1:18000/healthz | jq -e '.status == "ok"' >/dev/null
curl --fail --silent http://127.0.0.1:18000/metrics | grep -q 'platform_requests_total'
kubectl -n platform-system port-forward service/operator-console 18083:8080 >/tmp/ai-platform-console-port-forward.log 2>&1 &
console_forward_pid=$!
trap 'kill "$port_forward_pid" "$console_forward_pid" 2>/dev/null || true' EXIT
for _ in {1..30}; do
  if curl --fail --silent http://127.0.0.1:18083/healthz >/dev/null; then break; fi
  sleep 1
done
curl --fail --silent http://127.0.0.1:18083/ | grep -q 'Request capacity without receiving administrator credentials'
kubectl -n platform-observability port-forward service/prometheus-server 19090:80 >/tmp/ai-platform-prometheus-forward.log 2>&1 &
prometheus_forward_pid=$!
trap 'kill "$port_forward_pid" "$prometheus_forward_pid" 2>/dev/null || true' EXIT
for _ in {1..30}; do
  if curl --fail --silent http://127.0.0.1:19090/-/ready >/dev/null; then break; fi
  sleep 1
done
curl --fail --silent 'http://127.0.0.1:19090/api/v1/query?query=up' | jq -e '.status == "success"' >/dev/null
echo "Cloud pilot smoke passed: EKS, Argo, control plane, Operator Console, OPA, Prometheus, Grafana, and the metrics endpoint are reachable."
