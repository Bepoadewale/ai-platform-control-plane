#!/usr/bin/env bash
set -euo pipefail

# Bootstrap is intentionally project-scoped: it only touches the named EKS cluster and namespaces.
# Argo CD owns steady-state reconciliation after its Application is created below.
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
aws_region="${AWS_REGION:-us-east-1}"
cluster_name="${PILOT_CLUSTER_NAME:-ai-platform-control-plane-pilot}"
runtime_revision="${PILOT_RUNTIME_REVISION:-main}"

for command in aws kubectl helm jq openssl; do
  command -v "$command" >/dev/null 2>&1 || { echo "$command is required." >&2; exit 1; }
done
actual_account="$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || { echo "Unexpected AWS account." >&2; exit 1; }
[[ "$runtime_revision" =~ ^[A-Za-z0-9._/-]+$ ]] || { echo "Invalid PILOT_RUNTIME_REVISION." >&2; exit 1; }
AWS_PROFILE="$aws_profile" aws secretsmanager get-secret-value \
  --secret-id ai-platform-control-plane-pilot/gitops-publisher --region "$aws_region" \
  --query VersionId --output text >/dev/null || {
    echo "The scoped GitHub App secret has no value. Run make pilot-cloud-put-gitops-secret first." >&2
    exit 1
  }

AWS_PROFILE="$aws_profile" aws eks update-kubeconfig --name "$cluster_name" --region "$aws_region"
kubectl get nodes --request-timeout=30s >/dev/null

# The identity and telemetry components have no public load balancer. Pilot evidence uses local
# port-forwarding so this short run does not create another billable service.
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo add external-secrets https://charts.external-secrets.io >/dev/null
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null
helm repo update >/dev/null
kubectl create namespace platform-observability --dry-run=client -o yaml | kubectl apply -f -
kubectl -n platform-observability create configmap ai-platform-control-plane-dashboard \
  --from-file=control-plane.json="$project_root/platform/observability/grafana/dashboards/control-plane.json" \
  --dry-run=client -o yaml | kubectl apply -f -
if ! kubectl -n argocd rollout status deployment/argocd-server --timeout=5s >/dev/null 2>&1; then
  helm upgrade --install argocd argo/argo-cd --namespace argocd --create-namespace \
    --set server.service.type=ClusterIP --wait --timeout 10m
else
  echo "Argo CD is already Ready; skipping Helm upgrade."
fi
# ApplicationSet controllers commonly watch only Argo CD's own namespace. Keep this
# cluster-scoped Git generator in argocd (not the platform Kustomize namespace) so it
# can create per-environment Applications from reviewed desired-state changes.
kubectl apply -f "$project_root/platform/cloud/argocd/environment-applicationset.yaml"
external_secrets_role_arn="$(AWS_PROFILE="$aws_profile" aws iam get-role \
  --role-name ai-platform-control-plane-pilot-external-secrets \
  --query 'Role.Arn' --output text)"
if ! kubectl -n external-secrets rollout status deployment/external-secrets --timeout=5s >/dev/null 2>&1; then
  helm upgrade --install external-secrets external-secrets/external-secrets \
    --namespace external-secrets --create-namespace \
    --set serviceAccount.create=true \
    --set serviceAccount.name=external-secrets \
    --set serviceAccount.annotations."eks\\.amazonaws\\.com/role-arn"="$external_secrets_role_arn" \
    --wait --timeout 10m
else
  echo "External Secrets Operator is already Ready; skipping Helm upgrade."
fi
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
# Keycloak reads bootstrap credentials only when its Pod starts. Preserve a previously created
# pilot secret across an idempotent bootstrap instead of silently changing the stored password
# beneath a healthy Keycloak instance.
if ! kubectl -n platform-system get secret platform-runtime-secrets >/dev/null 2>&1; then
  kubectl -n platform-system create secret generic platform-runtime-secrets \
    --from-literal=database-url="$database_url" \
    --from-literal=keycloak-admin-username=pilot-admin \
    --from-literal=keycloak-admin-password="$(openssl rand -base64 24)"
else
  echo "Runtime bootstrap secret already exists; preserving its Keycloak bootstrap credential."
fi

kubectl apply -f "$project_root/platform/cloud/runtime/external-secrets.yaml"
kubectl -n platform-system wait --for=condition=Ready externalsecret/github-app-credentials --timeout=5m

runtime_manifest="$(mktemp "${TMPDIR:-/tmp}/ai-platform-runtime-application.XXXXXX.yaml")"
trap 'rm -f "${runtime_manifest:-}"' EXIT
sed "s#targetRevision: main#targetRevision: ${runtime_revision}#" \
  "$project_root/platform/cloud/argocd/runtime-application.yaml" >"$runtime_manifest"
kubectl apply -f "$runtime_manifest"
kubectl -n argocd rollout status deployment/argocd-server --timeout=10m
kubectl -n argocd wait --for=jsonpath='{.status.sync.status}'=Synced application/ai-platform-control-plane-runtime --timeout=10m
# Argo CD reports this mixed application as Degraded when it cannot derive health for
# third-party CRs (for example, an ExternalSecret or ApplicationSet). Sync is the Git
# reconciliation assertion; the following explicit readiness gates are authoritative for
# the workloads and secret that this pilot owns.
kubectl -n platform-system wait --for=condition=Ready externalsecret/github-app-credentials --timeout=5m
kubectl -n platform-system rollout status deployment/opa --timeout=5m
kubectl -n platform-system rollout status deployment/keycloak --timeout=10m
kubectl -n platform-system rollout status deployment/control-plane --timeout=5m
kubectl -n platform-system rollout status deployment/gitops-worker --timeout=5m
kubectl -n platform-system rollout status deployment/status-observer --timeout=5m
kubectl -n platform-system rollout status deployment/operator-console --timeout=5m
kubectl -n platform-system rollout status deployment/otel-collector --timeout=5m
kubectl -n platform-observability rollout status deployment/prometheus-server --timeout=5m
kubectl -n platform-observability rollout status deployment/grafana --timeout=5m
echo "Runtime is Argo Synced from revision $runtime_revision and all project workload/secret readiness gates passed. Run make pilot-cloud-smoke for bounded API, policy and telemetry checks."
