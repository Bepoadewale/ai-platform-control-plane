#!/usr/bin/env bash
set -euo pipefail

# A GitHub Actions role cannot create itself. This narrow, account-guarded bootstrap creates only
# the GitHub OIDC provider and the two manual-workflow roles; the hosted workflow then creates and
# destroys the full pilot footprint with short-lived credentials.
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
terraform_root="$project_root/infrastructure/terraform/pilot"
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
aws_region="${AWS_REGION:-us-east-1}"
state_bucket="ai-platform-control-plane-tfstate-${expected_account}"
lock_table="ai-platform-control-plane-pilot-terraform-locks"

[[ "${BOOTSTRAP_GITHUB_OIDC:-}" == "$expected_account" ]] || {
  echo "Refusing OIDC bootstrap. Set BOOTSTRAP_GITHUB_OIDC=$expected_account." >&2
  exit 1
}
for command in aws terraform; do
  command -v "$command" >/dev/null || { echo "$command is required." >&2; exit 1; }
done
actual_account="$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || { echo "Unexpected AWS account." >&2; exit 1; }

cd "$terraform_root"
AWS_PROFILE="$aws_profile" AWS_SDK_LOAD_CONFIG=1 terraform init -reconfigure \
  -backend-config="bucket=$state_bucket" \
  -backend-config="key=pilot/terraform.tfstate" \
  -backend-config="region=$aws_region" \
  -backend-config="dynamodb_table=$lock_table" \
  -backend-config="encrypt=true" >/dev/null
AWS_PROFILE="$aws_profile" AWS_SDK_LOAD_CONFIG=1 TF_VAR_expected_account_id="$expected_account" \
  terraform apply -auto-approve \
  -target=aws_iam_openid_connect_provider.github \
  -target=aws_iam_role.github_readonly \
  -target=aws_iam_role_policy.github_readonly \
  -target=aws_iam_role.github_terraform \
  -target=aws_iam_role_policy.github_terraform

echo "GitHub OIDC bootstrap complete. The next mutation must use the hosted workflow role:"
echo "arn:aws:iam::${expected_account}:role/ai-platform-control-plane-pilot-github-terraform"
