#!/usr/bin/env bash
set -euo pipefail

# Bounded availability proof for the disposable AWS pilot.  This deliberately deletes
# one ready API pod and one ready worker pod; it never touches a node, database, or a
# resource outside the project-labelled runtime namespace.
cluster_name="${PILOT_CLUSTER_NAME:-ai-platform-control-plane-pilot}"
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
aws_region="${AWS_REGION:-us-east-1}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
namespace="platform-system"

actual_account="$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || { echo "Unexpected AWS account." >&2; exit 1; }
AWS_PROFILE="$aws_profile" aws eks update-kubeconfig --name "$cluster_name" --region "$aws_region" >/dev/null

available_replicas() {
  kubectl -n "$namespace" get deployment "$1" -o jsonpath='{.status.availableReplicas}'
}

[[ "$(available_replicas control-plane)" == "2" ]] || { echo "Control plane is not at two available replicas." >&2; exit 1; }
[[ "$(available_replicas gitops-worker)" == "2" ]] || { echo "GitOps worker is not at two available replicas." >&2; exit 1; }
[[ "$(kubectl -n "$namespace" get pdb control-plane -o jsonpath='{.status.disruptionsAllowed}')" =~ ^[1-9][0-9]*$ ]] || {
  echo "Control-plane PodDisruptionBudget does not currently allow one disruption." >&2; exit 1;
}
[[ "$(kubectl -n "$namespace" get pdb gitops-worker -o jsonpath='{.status.disruptionsAllowed}')" =~ ^[1-9][0-9]*$ ]] || {
  echo "GitOps-worker PodDisruptionBudget does not currently allow one disruption." >&2; exit 1;
}

api_pod="$(kubectl -n "$namespace" get pods -l app.kubernetes.io/name=control-plane \
  --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')"
worker_pod="$(kubectl -n "$namespace" get pods -l app.kubernetes.io/name=gitops-worker \
  --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')"
[[ -n "$api_pod" && -n "$worker_pod" ]] || { echo "Expected ready API and worker pods." >&2; exit 1; }

port_forward_pid=""
cleanup() { [[ -n "$port_forward_pid" ]] && kill "$port_forward_pid" 2>/dev/null || true; }
trap cleanup EXIT
kubectl -n "$namespace" port-forward service/control-plane 18000:8000 >/tmp/ai-platform-ha-port-forward.log 2>&1 &
port_forward_pid=$!
for _ in {1..30}; do
  curl --fail --silent http://127.0.0.1:18000/healthz >/dev/null && break
  sleep 1
done
curl --fail --silent http://127.0.0.1:18000/healthz | jq -e '.status == "ok"' >/dev/null

kubectl -n "$namespace" delete pod "$api_pod" --wait=true
kubectl -n "$namespace" rollout status deployment/control-plane --timeout=5m
[[ "$(available_replicas control-plane)" == "2" ]] || { echo "API did not recover two replicas." >&2; exit 1; }
curl --fail --silent http://127.0.0.1:18000/healthz | jq -e '.status == "ok"' >/dev/null

kubectl -n "$namespace" delete pod "$worker_pod" --wait=true
kubectl -n "$namespace" rollout status deployment/gitops-worker --timeout=5m
[[ "$(available_replicas gitops-worker)" == "2" ]] || { echo "Worker did not recover two replicas." >&2; exit 1; }

echo "Cloud HA check passed: API and durable GitOps worker maintained two replicas after scoped pod-loss recovery; PDBs allowed one disruption."
