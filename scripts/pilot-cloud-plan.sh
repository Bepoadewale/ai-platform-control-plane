#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
terraform_root="$project_root/infrastructure/terraform/pilot"
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
aws_region="${AWS_REGION:-us-east-1}"
state_bucket="ai-platform-control-plane-tfstate-${expected_account}"
lock_table="ai-platform-control-plane-pilot-terraform-locks"

if ! command -v terraform >/dev/null 2>&1 || ! command -v aws >/dev/null 2>&1; then
  echo "Terraform and AWS CLI are required." >&2
  exit 1
fi

actual_account="$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)"
if [[ "$actual_account" != "$expected_account" ]]; then
  echo "Refusing to target account $actual_account; expected $expected_account." >&2
  exit 1
fi

cd "$terraform_root"
AWS_PROFILE="$aws_profile" AWS_SDK_LOAD_CONFIG=1 terraform init -reconfigure \
  -backend-config="bucket=$state_bucket" \
  -backend-config="key=pilot/terraform.tfstate" \
  -backend-config="region=$aws_region" \
  -backend-config="dynamodb_table=$lock_table" \
  -backend-config="encrypt=true"

AWS_PROFILE="$aws_profile" AWS_SDK_LOAD_CONFIG=1 \
  TF_VAR_expected_account_id="$expected_account" \
  terraform plan "$@"
