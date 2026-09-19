#!/usr/bin/env bash
set -euo pipefail

command -v kind >/dev/null || { echo "kind is required: https://kind.sigs.k8s.io"; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl is required"; exit 1; }
command -v helm >/dev/null || { echo "helm is required"; exit 1; }

cluster_name="ai-platform-local"
if ! kind get clusters | grep -qx "$cluster_name"; then
  kind create cluster --name "$cluster_name"
fi

# The chart is applied directly for a local data-plane proof. Argo CD installation
# is intentionally an explicit operator step; see docs/local-development.md.
helm upgrade --install golden-path platform/helm/golden-path \
  --namespace platform-demo --create-namespace \
  --set namespace=team-demo-demo-api
kubectl get namespace team-demo-demo-api
