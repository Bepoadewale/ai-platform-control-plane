#!/usr/bin/env bash
set -euo pipefail

command -v kind >/dev/null || { echo "kind is required: https://kind.sigs.k8s.io"; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl is required"; exit 1; }
command -v helm >/dev/null || { echo "helm is required"; exit 1; }
command -v docker >/dev/null || { echo "Docker Desktop is required"; exit 1; }

docker info >/dev/null || { echo "Docker Desktop must be running"; exit 1; }

cluster_name="ai-platform-local"
kind_node_image="${KIND_NODE_IMAGE:-kindest/node:v1.34.0}"
metrics_server_chart_version="${METRICS_SERVER_CHART_VERSION:-3.14.0}"
argocd_chart_version="${ARGOCD_CHART_VERSION:-10.9.2}"
if ! kind get clusters | grep -qx "$cluster_name"; then
  kind create cluster --name "$cluster_name" --image "$kind_node_image"
fi

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ --force-update
helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo update metrics-server argo

helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --version "$metrics_server_chart_version" \
  --set 'args[0]=--kubelet-insecure-tls' \
  --wait --timeout 5m

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --version "$argocd_chart_version" \
  --set server.service.type=ClusterIP \
  --wait --timeout 8m

# Argo CD 3.x stores child-resource health externally by default. Persist it in
# the local demo so `make argocd-demo` can wait for Application Synced/Healthy.
kubectl patch configmap argocd-cmd-params-cm --namespace argocd --type merge \
  --patch '{"data":{"controller.resource.health.persist":"true"}}'
kubectl rollout restart statefulset/argocd-application-controller --namespace argocd
kubectl rollout status statefulset/argocd-application-controller --namespace argocd --timeout=180s

echo "PASS: kind, Metrics Server, and Argo CD are ready for local demos."
