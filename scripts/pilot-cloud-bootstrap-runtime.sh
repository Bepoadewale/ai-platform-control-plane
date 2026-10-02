#!/usr/bin/env bash
set -euo pipefail

# Bootstrap is intentionally project-scoped: it only touches the named EKS cluster and namespaces.
# Argo CD owns steady-state reconciliation after its Application is created below.
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
aws_region="${AWS_REGION:-us-east-1}"
cluster_name="${PILOT_CLUSTER_NAME:-ai-platform-control-plane-pilot}"

for command in aws kubectl helm jq openssl; do
  command -v "$command" >/dev/null 2>&1 || { echo "$command is required." >&2; exit 1; }
done
actual_account="$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || { echo "Unexpected AWS account." >&2; exit 1; }

AWS_PROFILE="$aws_profile" aws eks update-kubeconfig --name "$cluster_name" --region "$aws_region"
kubectl get nodes --request-timeout=30s >/dev/null

# The identity and telemetry components have no public load balancer. Pilot evidence uses local
# port-forwarding so this short run does not create another billable service.
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null
helm repo update >/dev/null
helm upgrade --install argocd argo/argo-cd --namespace argocd --create-namespace \
  --set server.service.type=ClusterIP --wait --timeout 10m
helm upgrade --install tempo grafana/tempo --namespace platform-observability --create-namespace \
  --set persistence.enabled=false --set resources.requests.cpu=100m --set resources.requests.memory=128Mi \
  --set resources.limits.cpu=500m --set resources.limits.memory=256Mi --wait --timeout 10m
helm upgrade --install prometheus prometheus-community/prometheus --namespace platform-observability \
  -f "$project_root/platform/cloud/observability/prometheus-values.yaml" --wait --timeout 10m
helm upgrade --install grafana grafana/grafana --namespace platform-observability \
  -f "$project_root/platform/cloud/observability/grafana-values.yaml" --wait --timeout 10m

master_secret_arn="$(AWS_PROFILE="$aws_profile" aws rds describe-db-instances \
  --db-instance-identifier ai-platform-control-plane-pilot-postgres \
  --region "$aws_region" --query 'DBInstances[0].MasterUserSecret.SecretArn' --output text)"
db_host="$(AWS_PROFILE="$aws_profile" aws rds describe-db-instances \
  --db-instance-identifier ai-platform-control-plane-pilot-postgres \
  --region "$aws_region" --query 'DBInstances[0].Endpoint.Address' --output text)"
master_secret="$(AWS_PROFILE="$aws_profile" aws secretsmanager get-secret-value --secret-id "$master_secret_arn" --region "$aws_region" --query SecretString --output text)"
db_username="$(jq -r '.username' <<<"$master_secret")"
db_password="$(jq -r '.password' <<<"$master_secret")"
database_url="postgresql://${db_username}:${db_password}@${db_host}:5432/platform"

# Runtime values remain only in the Kubernetes API for this one-hour pilot. They are not committed
# and Terraform never reads them. EKS Pod Identity + External Secrets is a subsequent hardening gate.
kubectl create namespace platform-system --dry-run=client -o yaml | kubectl apply -f -
kubectl -n platform-system create secret generic platform-runtime-secrets \
  --from-literal=database-url="$database_url" \
  --from-literal=keycloak-admin-username=pilot-admin \
  --from-literal=keycloak-admin-password="$(openssl rand -base64 24)" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "$project_root/platform/cloud/argocd/runtime-application.yaml"
kubectl -n argocd rollout status deployment/argocd-server --timeout=10m
kubectl -n argocd wait --for=jsonpath='{.status.sync.status}'=Synced application/ai-platform-control-plane-runtime --timeout=10m
kubectl -n argocd wait --for=jsonpath='{.status.health.status}'=Healthy application/ai-platform-control-plane-runtime --timeout=10m
kubectl -n platform-system rollout status deployment/opa --timeout=5m
kubectl -n platform-system rollout status deployment/keycloak --timeout=10m
kubectl -n platform-system rollout status deployment/control-plane --timeout=5m
kubectl -n platform-system rollout status deployment/otel-collector --timeout=5m
kubectl -n platform-observability rollout status deployment/prometheus-server --timeout=5m
kubectl -n platform-observability rollout status deployment/grafana --timeout=5m
echo "Runtime is Argo Synced/Healthy. Run make pilot-cloud-smoke for bounded API, policy and telemetry checks."
