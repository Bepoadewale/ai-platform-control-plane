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

kubectl patch configmap argocd-cmd-params-cm --namespace argocd --type merge \
  --patch '{"data":{"controller.resource.health.persist":"true"}}'
kubectl rollout restart statefulset/argocd-application-controller --namespace argocd
kubectl rollout status statefulset/argocd-application-controller --namespace argocd --timeout=180s

kubectl apply -f platform/argocd/golden-path-application.yaml
kubectl patch application platform-environments --namespace argocd --type merge \
  --patch "{\"spec\":{\"source\":{\"targetRevision\":\"${target_revision}\",\"helm\":{\"values\":\"autoscaling:\\n  enabled: false\\ningress:\\n  enabled: false\\n\"}},\"syncPolicy\":{\"automated\":{\"prune\":true,\"selfHeal\":false}}}}"
kubectl annotate application platform-environments --namespace argocd \
  argocd.argoproj.io/refresh=hard --overwrite

for _ in $(seq 1 60); do
  status="$(kubectl get application platform-environments --namespace argocd \
    -o jsonpath='{.status.sync.status}/{.status.health.status}')"
  if [[ "$status" == "Synced/Healthy" ]]; then
    echo "PASS: Argo CD synchronized and observed a healthy golden path at ${target_revision}."
    exit 0
  fi
  sleep 2
done

echo "Argo CD application did not become Synced/Healthy (last status: ${status})." >&2
exit 1
