#!/usr/bin/env bash
set -euo pipefail

# This script is deliberately hostile to accidental use. It applies only the reviewed pilot plan
# into the exact account and persists the binary plan outside the repository.
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
terraform_root="$project_root/infrastructure/terraform/pilot"
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
aws_region="${AWS_REGION:-us-east-1}"
state_bucket="ai-platform-control-plane-tfstate-${expected_account}"
lock_table="ai-platform-control-plane-pilot-terraform-locks"
plan_dir="$project_root/.pilot"
plan_file="$plan_dir/cloud-pilot.tfplan"

if [[ "${APPLY_CLOUD_PILOT:-}" != "$expected_account" ]]; then
  echo "Refusing apply. Set APPLY_CLOUD_PILOT=$expected_account after reviewing make pilot-cloud-plan." >&2
  exit 1
fi

for command in terraform aws; do
  command -v "$command" >/dev/null 2>&1 || { echo "$command is required." >&2; exit 1; }
done

actual_account="$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || {
  echo "Refusing account $actual_account; expected $expected_account." >&2
  exit 1
}

mkdir -p "$plan_dir"
cd "$terraform_root"
AWS_PROFILE="$aws_profile" AWS_SDK_LOAD_CONFIG=1 terraform init -reconfigure \
  -backend-config="bucket=$state_bucket" \
  -backend-config="key=pilot/terraform.tfstate" \
  -backend-config="region=$aws_region" \
  -backend-config="dynamodb_table=$lock_table" \
  -backend-config="encrypt=true"
AWS_PROFILE="$aws_profile" AWS_SDK_LOAD_CONFIG=1 TF_VAR_expected_account_id="$expected_account" \
  terraform plan -out="$plan_file"
AWS_PROFILE="$aws_profile" AWS_SDK_LOAD_CONFIG=1 terraform apply "$plan_file"

echo "Cloud foundation applied. Next: make pilot-cloud-push-image, make pilot-cloud-bootstrap-runtime, make pilot-cloud-smoke."
