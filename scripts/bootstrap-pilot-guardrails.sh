#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
terraform_root="$project_root/infrastructure/terraform/bootstrap"
terraform_binary="${TERRAFORM_BIN:-terraform}"
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
aws_region="${AWS_REGION:-us-east-1}"
state_bucket="ai-platform-control-plane-tfstate-${expected_account}"
lock_table="ai-platform-control-plane-pilot-terraform-locks"

if ! command -v aws >/dev/null 2>&1; then
  echo "AWS CLI is required. Configure a local AWS SSO or IAM-user profile first." >&2
  exit 1
fi

if ! command -v "$terraform_binary" >/dev/null 2>&1; then
  echo "Terraform is required. Install a supported Terraform CLI or set TERRAFORM_BIN." >&2
  exit 1
fi

actual_account="$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)"
if [[ "$actual_account" != "$expected_account" ]]; then
  echo "Refusing to target account $actual_account; expected $expected_account." >&2
  exit 1
fi

if [[ -z "${PILOT_BUDGET_EMAIL:-}" ]]; then
  echo "PILOT_BUDGET_EMAIL is required and must not be committed." >&2
  exit 1
fi

aws_command() {
  AWS_PROFILE="$aws_profile" AWS_REGION="$aws_region" aws "$@"
}

if ! aws_command s3api head-bucket --bucket "$state_bucket" 2>/dev/null; then
  echo "Creating project-scoped Terraform state bucket: $state_bucket"
  aws_command s3api create-bucket --bucket "$state_bucket"
fi

# Secure the backend before Terraform writes any state to it. Terraform imports and continuously
# reconciles these same settings immediately after backend initialization.
aws_command s3api put-public-access-block --bucket "$state_bucket" \
  --public-access-block-configuration 'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'
aws_command s3api put-bucket-ownership-controls --bucket "$state_bucket" \
  --ownership-controls 'Rules=[{ObjectOwnership=BucketOwnerEnforced}]'
aws_command s3api put-bucket-versioning --bucket "$state_bucket" \
  --versioning-configuration Status=Enabled
aws_command s3api put-bucket-encryption --bucket "$state_bucket" \
  --server-side-encryption-configuration 'Rules=[{ApplyServerSideEncryptionByDefault={SSEAlgorithm=AES256}}]'
aws_command s3api put-bucket-tagging --bucket "$state_bucket" \
  --tagging 'TagSet=[{Key=project,Value=ai-platform-control-plane},{Key=environment,Value=pilot},{Key=managed_by,Value=terraform},{Key=owner,Value=bepoadewale},{Key=cost_scope,Value=pilot}]'

if ! aws_command dynamodb describe-table --table-name "$lock_table" >/dev/null 2>&1; then
  echo "Creating project-scoped Terraform lock table: $lock_table"
  aws_command dynamodb create-table \
    --table-name "$lock_table" \
    --billing-mode PAY_PER_REQUEST \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --tags Key=project,Value=ai-platform-control-plane Key=environment,Value=pilot Key=managed_by,Value=terraform Key=owner,Value=bepoadewale Key=cost_scope,Value=pilot >/dev/null
  aws_command dynamodb wait table-exists --table-name "$lock_table"
fi

run_terraform() {
  (
    cd "$terraform_root"
    AWS_PROFILE="$aws_profile" \
      AWS_SDK_LOAD_CONFIG=1 \
      TF_VAR_expected_account_id="$expected_account" \
      TF_VAR_budget_alert_email="$PILOT_BUDGET_EMAIL" \
      TF_VAR_monthly_budget_usd="10" \
      "$terraform_binary" "$@"
  )
}

run_terraform init -reconfigure \
  -backend-config="bucket=$state_bucket" \
  -backend-config="key=bootstrap/terraform.tfstate" \
  -backend-config="region=$aws_region" \
  -backend-config="dynamodb_table=$lock_table" \
  -backend-config="encrypt=true"

import_if_missing() {
  local resource="$1"
  local identifier="$2"
  if ! run_terraform state show "$resource" >/dev/null 2>&1; then
    run_terraform import "$resource" "$identifier" >/dev/null
  fi
}

import_if_missing aws_s3_bucket.terraform_state "$state_bucket"
import_if_missing aws_s3_bucket_public_access_block.terraform_state "$state_bucket"
import_if_missing aws_s3_bucket_ownership_controls.terraform_state "$state_bucket"
import_if_missing aws_s3_bucket_versioning.terraform_state "$state_bucket"
import_if_missing aws_s3_bucket_server_side_encryption_configuration.terraform_state "$state_bucket"
import_if_missing aws_dynamodb_table.terraform_locks "$lock_table"
run_terraform plan -out=pilot-guardrails.tfplan

if [[ "${APPLY_GUARDRAILS:-}" != "$expected_account" ]]; then
  echo
  echo "Plan only. To apply the reviewed $10 guardrails, rerun with:"
  echo "  APPLY_GUARDRAILS=$expected_account PILOT_BUDGET_EMAIL=<alert-email> $0"
  exit 0
fi

run_terraform apply pilot-guardrails.tfplan

echo "Pilot guardrails applied: budget alerts, encrypted/versioned state bucket, and lock table."
echo "AWS Budgets alerts are not a guaranteed spend stop; destroy paid resources promptly."
