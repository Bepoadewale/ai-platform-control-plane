#!/usr/bin/env bash
set -euo pipefail

# Applies the version under test to the local Argo CD instance. The checked-in
# Application deliberately tracks main; this script makes a local, explicit
# override so an unmerged PR can be validated without changing production
# desired state.
target_revision="${ARGOCD_TARGET_REVISION:-$(git branch --show-current)}"

if [[ -z "$target_revision" ]]; then
  echo "Unable to determine a Git revision; set ARGOCD_TARGET_REVISION." >&2
  exit 1
fi

kubectl apply -f platform/argocd/golden-path-application.yaml
kubectl patch application platform-environments --namespace argocd --type merge \
  --patch "{\"spec\":{\"source\":{\"targetRevision\":\"${target_revision}\",\"helm\":{\"values\":\"autoscaling:\\n  enabled: false\\n\"}}}}"
kubectl delete hpa sample-api --namespace team-demo-sample-api --ignore-not-found
kubectl annotate application platform-environments --namespace argocd \
  argocd.argoproj.io/refresh=hard --overwrite
echo "Applied local Argo CD validation override for revision ${target_revision}."
