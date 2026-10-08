#!/usr/bin/env bash
set -euo pipefail

# Deletes only Terraform-managed pilot resources. It never prunes account-wide resources.
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
terraform_root="$project_root/infrastructure/terraform/pilot"
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
aws_region="${AWS_REGION:-us-east-1}"
state_bucket="ai-platform-control-plane-tfstate-${expected_account}"
lock_table="ai-platform-control-plane-pilot-terraform-locks"

if [[ "${DESTROY_CLOUD_PILOT:-}" != "$expected_account" ]]; then
  echo "Refusing destroy. Set DESTROY_CLOUD_PILOT=$expected_account after collecting validation evidence." >&2
  exit 1
fi

for command in terraform aws kubectl; do
  command -v "$command" >/dev/null 2>&1 || { echo "$command is required." >&2; exit 1; }
done

actual_account="$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || {
  echo "Refusing account $actual_account; expected $expected_account." >&2
  exit 1
}

# The AWS Load Balancer Controller owns the project ALB rather than Terraform state. Remove only
# this named resource before destroying the EKS/VPC footprint so no orphaned endpoint or VPC
# dependency remains.
alb_name="ai-platform-cp-pilot"
alb_arn="$(AWS_PROFILE="$aws_profile" aws elbv2 describe-load-balancers --region "$aws_region" \
  --names "$alb_name" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || true)"
if [[ -n "$alb_arn" && "$alb_arn" != "None" ]]; then
  if AWS_PROFILE="$aws_profile" aws eks describe-cluster --name ai-platform-control-plane-pilot --region "$aws_region" >/dev/null 2>&1; then
    aws eks update-kubeconfig --profile "$aws_profile" --name ai-platform-control-plane-pilot --region "$aws_region" >/dev/null
    kubectl -n platform-system delete -f "$project_root/platform/cloud/runtime/public-ingress.yaml" --ignore-not-found >/dev/null 2>&1 || true
  fi
  for _ in {1..60}; do
    AWS_PROFILE="$aws_profile" aws elbv2 describe-load-balancers --region "$aws_region" --names "$alb_name" >/dev/null 2>&1 || break
    sleep 5
  done
  if AWS_PROFILE="$aws_profile" aws elbv2 describe-load-balancers --region "$aws_region" --names "$alb_name" >/dev/null 2>&1; then
    echo "Public ALB did not disappear after Ingress deletion; deleting only the named pilot ALB." >&2
    AWS_PROFILE="$aws_profile" aws elbv2 delete-load-balancer --region "$aws_region" --load-balancer-arn "$alb_arn"
    AWS_PROFILE="$aws_profile" aws elbv2 wait load-balancers-deleted --region "$aws_region" --load-balancer-arns "$alb_arn"
  fi
fi

cd "$terraform_root"
AWS_PROFILE="$aws_profile" AWS_SDK_LOAD_CONFIG=1 terraform init -reconfigure \
  -backend-config="bucket=$state_bucket" \
  -backend-config="key=pilot/terraform.tfstate" \
  -backend-config="region=$aws_region" \
  -backend-config="dynamodb_table=$lock_table" \
  -backend-config="encrypt=true"
AWS_PROFILE="$aws_profile" AWS_SDK_LOAD_CONFIG=1 TF_VAR_expected_account_id="$expected_account" \
  terraform destroy -auto-approve

echo "Verifying that the project-scoped workload footprint is absent."
if AWS_PROFILE="$aws_profile" aws eks describe-cluster --name ai-platform-control-plane-pilot --region "$aws_region" >/dev/null 2>&1; then
  echo "EKS cluster still exists after destroy." >&2
  exit 1
fi
if AWS_PROFILE="$aws_profile" aws rds describe-db-instances --db-instance-identifier ai-platform-control-plane-pilot-postgres --region "$aws_region" >/dev/null 2>&1; then
  echo "RDS instance still exists after destroy." >&2
  exit 1
fi
if AWS_PROFILE="$aws_profile" aws elbv2 describe-load-balancers --region "$aws_region" --names "$alb_name" >/dev/null 2>&1; then
  echo "Public pilot ALB still exists after destroy." >&2
  exit 1
fi
echo "Pilot workload resources are absent. The Phase 0 state bucket, lock table, and Budget remain intentionally retained."
