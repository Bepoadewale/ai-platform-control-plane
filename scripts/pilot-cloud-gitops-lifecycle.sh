#!/usr/bin/env bash
set -euo pipefail

# Runs one disposable environment through API → durable worker → GitHub PR → merged desired state
# → Argo ApplicationSet → EKS Deployment → observer → deletion PR → Argo prune. The merge is
# deliberately opt-in and branch-scoped; default mode stops after presenting the generated PR.
cluster_name="${PILOT_CLUSTER_NAME:-ai-platform-control-plane-pilot}"
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
aws_region="${AWS_REGION:-us-east-1}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
name="${PILOT_GITOPS_ENVIRONMENT_NAME:-cloud-gitops-demo}"
api_port="${PILOT_GITOPS_API_PORT:-18084}"
token_pod="pilot-gitops-token-$RANDOM"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/ai-platform-gitops.XXXXXX")"
api_pid=""

cleanup() {
  [[ -n "$api_pid" ]] && kill "$api_pid" 2>/dev/null || true
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

kubectl -n platform-system get deployment/gitops-worker -o jsonpath='{.status.availableReplicas}' | grep -qx '2'
kubectl -n platform-system get deployment/status-observer -o jsonpath='{.status.availableReplicas}' | grep -qx '1'
kubectl -n platform-system port-forward service/control-plane "$api_port:8000" >"$tmp_dir/api.log" 2>&1 & api_pid=$!
for _ in {1..45}; do
  curl --fail --silent "http://127.0.0.1:$api_port/healthz" >/dev/null && break
  sleep 1
done
curl --fail --silent "http://127.0.0.1:$api_port/healthz" >/dev/null

kubectl -n platform-system run "$token_pod" --restart=Never --image=curlimages/curl:8.10.1 \
  --command -- sh -ceu '
    curl -fsS -X POST http://keycloak:8080/realms/platform/protocol/openid-connect/token \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "client_id=ai-platform-control-plane" \
      -d "grant_type=password" -d "username=developer" -d "password=local-development-only"
  ' >/dev/null
kubectl -n platform-system wait --for=jsonpath='{.status.phase}'=Succeeded "pod/$token_pod" --timeout=90s >/dev/null
token="$(kubectl -n platform-system logs "$token_pod" | jq -er '.access_token')"

environment_id="${PILOT_GITOPS_ENVIRONMENT_ID:-}"
if [[ -z "$environment_id" ]]; then
  request_id="$(python3 -c 'import uuid; print(uuid.uuid4())')"
  jq -n --arg request_id "$request_id" --arg name "$name" '{
    request_id: $request_id,
    idempotency_key: ("cloud-gitops-" + $request_id),
    name: $name, team: "team-demo", environment_type: "development", ttl_hours: 1,
    services: ["api"], image: "nginxinc/nginx-unprivileged:1.27-alpine", observability: true,
    workload: {size: "small", replicas: 1, privileged: false, gpu_count: 0, min_replicas: 1, max_replicas: 1, scaling_policy: "cpu"},
    cost_center: "pilot"
  }' >"$tmp_dir/request.json"
  curl --fail --silent -X POST "http://127.0.0.1:$api_port/api/v1/environments" \
    -H "Authorization: Bearer $token" -H 'Content-Type: application/json' \
    --data-binary @"$tmp_dir/request.json" >"$tmp_dir/environment.json"
  jq -e '.state == "APPLYING"' "$tmp_dir/environment.json" >/dev/null
  environment_id="$(jq -er '.id' "$tmp_dir/environment.json")"
fi

for _ in {1..60}; do
  curl --fail --silent -H "Authorization: Bearer $token" \
    "http://127.0.0.1:$api_port/api/v1/environments/$environment_id/reconciliation-jobs" >"$tmp_dir/jobs.json"
  jq -e 'map(select(.action == "APPLY" and .state == "PUBLISHED")) | length >= 1' "$tmp_dir/jobs.json" >/dev/null && break
  sleep 2
done
merge_if_open() {
  local pull_request="$1"
  local state
  state="$(gh pr view "$pull_request" --json state --jq '.state')"
  if [[ "$state" == "MERGED" ]]; then
    echo "GitOps pull request is already merged: $pull_request"
    return 0
  fi
  [[ "$state" == "OPEN" ]] || { echo "GitOps pull request is not mergeable: $pull_request ($state)" >&2; return 1; }
  gh pr merge "$pull_request" --merge --delete-branch
}

apply_pr="$(jq -er 'map(select(.action == "APPLY" and .state == "PUBLISHED")) | sort_by(.created_at) | last.publication_url' "$tmp_dir/jobs.json")"
echo "GitOps apply pull request: $apply_pr"

if [[ "${MERGE_GITOPS_CHANGE:-}" != "$environment_id" && "${MERGE_GITOPS_CHANGE:-}" != "auto" ]]; then
  echo "Review the PR, then rerun with PILOT_GITOPS_ENVIRONMENT_ID=$environment_id MERGE_GITOPS_CHANGE=$environment_id to perform the explicit merge." >&2
  exit 0
fi
command -v gh >/dev/null 2>&1 || { echo "gh is required to merge the reviewed GitOps PR." >&2; exit 1; }
merge_if_open "$apply_pr"

namespace="team-demo-$name"
for _ in {1..90}; do
  kubectl -n "$namespace" get deployment "$name" -o jsonpath='{.status.availableReplicas}' 2>/dev/null | grep -qx '1' && break
  sleep 2
done
kubectl -n "$namespace" get deployment "$name" -o jsonpath='{.status.availableReplicas}' | grep -qx '1'
for _ in {1..60}; do
  curl --fail --silent -H "Authorization: Bearer $token" \
    "http://127.0.0.1:$api_port/api/v1/environments/$environment_id" >"$tmp_dir/ready.json"
  jq -e '.state == "READY"' "$tmp_dir/ready.json" >/dev/null && break
  sleep 2
done
jq -e '.state == "READY"' "$tmp_dir/ready.json" >/dev/null

if [[ "${PILOT_GITOPS_SKIP_DESTROY:-}" == "1" ]]; then
  echo "GitOps creation passed: approved intent → Git PR → Argo/EKS Ready. Environment id: $environment_id"
  echo "Destroy is intentionally deferred for the caller's bounded follow-up drill."
  exit 0
fi

curl --fail --silent -X POST -H "Authorization: Bearer $token" \
  "http://127.0.0.1:$api_port/api/v1/environments/$environment_id/destroy" >"$tmp_dir/destroy.json"
jq -e '.state == "DESTROYING"' "$tmp_dir/destroy.json" >/dev/null
for _ in {1..60}; do
  curl --fail --silent -H "Authorization: Bearer $token" \
    "http://127.0.0.1:$api_port/api/v1/environments/$environment_id/reconciliation-jobs" >"$tmp_dir/destroy-jobs.json"
  jq -e 'map(select(.action == "DESTROY" and .state == "PUBLISHED")) | length >= 1' "$tmp_dir/destroy-jobs.json" >/dev/null && break
  sleep 2
done
destroy_pr="$(jq -er 'map(select(.action == "DESTROY" and .state == "PUBLISHED")) | sort_by(.created_at) | last.publication_url' "$tmp_dir/destroy-jobs.json")"
echo "GitOps destroy pull request: $destroy_pr"
merge_if_open "$destroy_pr"

for _ in {1..90}; do
  ! kubectl get namespace "$namespace" >/dev/null 2>&1 && break
  sleep 2
done
! kubectl get namespace "$namespace" >/dev/null 2>&1
for _ in {1..60}; do
  curl --fail --silent -H "Authorization: Bearer $token" \
    "http://127.0.0.1:$api_port/api/v1/environments/$environment_id" >"$tmp_dir/destroyed.json"
  jq -e '.state == "DESTROYED"' "$tmp_dir/destroyed.json" >/dev/null && break
  sleep 2
done
jq -e '.state == "DESTROYED"' "$tmp_dir/destroyed.json" >/dev/null
echo "GitOps lifecycle passed: approved intent → Git PR → Argo/EKS Ready → Git deletion PR → Argo prune → audit state DESTROYED."
