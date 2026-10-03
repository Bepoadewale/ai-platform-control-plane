#!/usr/bin/env bash
set -euo pipefail

# Proves a GitOps rollback rather than treating container health as model/service quality. The
# control plane first creates a known-good workload through its normal durable worker/PR path. This
# script then creates two reviewed operator PRs: a bad-image regression and restoration of the
# exact prior values. Argo, Kubernetes, and the observer provide the evidence.
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cluster_name="${PILOT_CLUSTER_NAME:-ai-platform-control-plane-pilot}"
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
aws_region="${AWS_REGION:-us-east-1}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
repository="${PILOT_GITOPS_REPOSITORY:-Bepoadewale/ai-platform-control-plane}"
name="${PILOT_ROLLBACK_ENVIRONMENT_NAME:-cloud-rollback-demo}"
team="team-demo"
namespace="${team}-${name}"
values_path="environments/${team}/${name}/values.yaml"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/ai-platform-rollback.XXXXXX")"
api_pid=""; token_pod="pilot-rollback-token-$RANDOM"
cleanup() {
  [[ -n "$api_pid" ]] && kill "$api_pid" 2>/dev/null || true
  kubectl -n platform-system delete pod "$token_pod" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  rm -rf "$tmp_dir"
}
trap cleanup EXIT INT TERM

for command in aws kubectl curl jq gh base64 python3; do
  command -v "$command" >/dev/null || { echo "$command is required." >&2; exit 1; }
done
actual_account="$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || { echo "Unexpected AWS account." >&2; exit 1; }
aws eks update-kubeconfig --profile "$aws_profile" --name "$cluster_name" --region "$aws_region" >/dev/null

merge_when_checks_pass() {
  local pull_request="$1"
  # GitOps mutations obey the same protected-main checks as application code.
  # Waiting here prevents a race between PR creation and branch protection.
  gh pr checks "$pull_request" --repo "$repository" --watch --interval 10
  gh pr merge "$pull_request" --repo "$repository" --merge --delete-branch
}

# The initial release is the known-good state and is created only through the control plane's
# durable worker and GitHub App publication path.
PILOT_GITOPS_ENVIRONMENT_NAME="$name" \
MERGE_GITOPS_CHANGE=auto \
PILOT_GITOPS_SKIP_DESTROY=1 \
"$project_root/scripts/pilot-cloud-gitops-lifecycle.sh" >/dev/null
kubectl -n "$namespace" get deployment "$name" -o jsonpath='{.status.availableReplicas}' | grep -qx '1'

get_values() {
  gh api "repos/$repository/contents/$values_path?ref=main" --jq '.content' | tr -d '\n' | base64 --decode
}
write_pr() {
  local content_file="$1" title="$2" branch="$3"
  local base_sha current_sha encoded pr
  base_sha="$(gh api "repos/$repository/git/ref/heads/main" --jq '.object.sha')"
  current_sha="$(gh api "repos/$repository/contents/$values_path?ref=main" --jq '.sha')"
  gh api --method POST "repos/$repository/git/refs" -f "ref=refs/heads/$branch" -f "sha=$base_sha" >/dev/null
  encoded="$(base64 <"$content_file" | tr -d '\n')"
  gh api --method PUT "repos/$repository/contents/$values_path" \
    -f "message=$title" -f "content=$encoded" -f "branch=$branch" -f "sha=$current_sha" >/dev/null
  pr="$(gh pr create --repo "$repository" --base main --head "$branch" --title "$title" --body 'Disposable, reviewed cloud-pilot rollback drill.')"
  merge_when_checks_pass "$pr"
}

get_values >"$tmp_dir/known-good-values.yaml"
python3 - "$tmp_dir/known-good-values.yaml" "$tmp_dir/bad-values.yaml" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
lines = [
    "image: registry.invalid/ai-platform-control-plane:rollback-drill"
    if line.startswith("image: ") else line
    for line in source.splitlines()
]
Path(sys.argv[2]).write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
bad_branch="pilot/rollback-bad-${name}-$(date +%s)"
write_pr "$tmp_dir/bad-values.yaml" "gitops: inject bounded rollback regression for $team/$name" "$bad_branch"

failed=false
for _ in {1..90}; do
  if kubectl -n "$namespace" get deployment "$name" -o json | jq -e '.status.conditions[]? | select(.type == "Progressing" and .status == "False")' >/dev/null; then
    failed=true
    break
  fi
  sleep 2
done
[[ "$failed" == true ]] || { echo "Bad-image regression did not reach Progressing=False." >&2; exit 1; }

restore_branch="pilot/rollback-restore-${name}-$(date +%s)"
write_pr "$tmp_dir/known-good-values.yaml" "gitops: restore known-good values for $team/$name" "$restore_branch"
for _ in {1..90}; do
  kubectl -n "$namespace" get deployment "$name" -o jsonpath='{.status.availableReplicas}' 2>/dev/null | grep -qx '1' && break
  sleep 2
done
kubectl -n "$namespace" get deployment "$name" -o jsonpath='{.status.availableReplicas}' | grep -qx '1'

# Finish through the governed API, preserving the normal audit/durable-delete path.
kubectl -n platform-system run "$token_pod" --restart=Never --image=curlimages/curl:8.10.1 --command -- sh -ceu '
  curl -fsS -X POST http://keycloak:8080/realms/platform/protocol/openid-connect/token \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=ai-platform-control-plane" -d "grant_type=password" \
    -d "username=developer" -d "password=local-development-only"
' >/dev/null
kubectl -n platform-system wait --for=jsonpath='{.status.phase}'=Succeeded "pod/$token_pod" --timeout=90s >/dev/null
token="$(kubectl -n platform-system logs "$token_pod" | jq -er '.access_token')"
kubectl -n platform-system port-forward service/control-plane 18085:8000 >"$tmp_dir/api.log" 2>&1 & api_pid=$!
for _ in {1..30}; do curl -fs http://127.0.0.1:18085/healthz >/dev/null && break; sleep 1; done
environment_id="$(curl -fsS -H "Authorization: Bearer $token" http://127.0.0.1:18085/api/v1/environments | jq -er --arg name "$name" '.[] | select(.request.name == $name) | .id')"
curl -fsS -X POST -H "Authorization: Bearer $token" "http://127.0.0.1:18085/api/v1/environments/$environment_id/destroy" >/dev/null
for _ in {1..60}; do
  jobs="$(curl -fsS -H "Authorization: Bearer $token" "http://127.0.0.1:18085/api/v1/environments/$environment_id/reconciliation-jobs")"
  jq -e 'map(select(.action == "DESTROY" and .state == "PUBLISHED")) | length >= 1' <<<"$jobs" >/dev/null && break
  sleep 2
done
destroy_pr="$(jq -er 'map(select(.action == "DESTROY" and .state == "PUBLISHED")) | sort_by(.created_at) | last.publication_url' <<<"$jobs")"
merge_when_checks_pass "$destroy_pr"
for _ in {1..90}; do ! kubectl get namespace "$namespace" >/dev/null 2>&1 && break; sleep 2; done
! kubectl get namespace "$namespace" >/dev/null 2>&1
echo "GitOps rollback drill passed: known-good Ready → reviewed bad-image regression → observed failure → reviewed restore → Ready → governed destroy/prune."
