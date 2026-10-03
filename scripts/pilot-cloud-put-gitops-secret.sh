#!/usr/bin/env bash
set -euo pipefail

# Uploads the locally held GitHub App key directly to the pilot Secret. Terraform never receives
# this value, and the temporary JSON file is deleted even if the AWS call fails.
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
aws_region="${AWS_REGION:-us-east-1}"
app_id="${GITHUB_APP_ID:-5159790}"
installation_id="${GITHUB_APP_INSTALLATION_ID:-167128937}"
private_key="${GITHUB_APP_PRIVATE_KEY_PATH:-$HOME/.config/ai-platform-control-plane/github-app.pem}"
secret_name="ai-platform-control-plane-pilot/gitops-publisher"

command -v aws >/dev/null || { echo "aws is required." >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required." >&2; exit 1; }
[[ -f "$private_key" ]] || { echo "GitHub App private key is unavailable." >&2; exit 1; }
actual_account="$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || { echo "Unexpected AWS account." >&2; exit 1; }

umask 077
payload="$(mktemp "${TMPDIR:-/tmp}/ai-platform-github-app.XXXXXX.json")"
trap 'rm -f "$payload"' EXIT
jq -n --rawfile private_key "$private_key" \
  --arg app_id "$app_id" --arg installation_id "$installation_id" \
  '{"app-id": $app_id, "installation-id": $installation_id, "private-key.pem": $private_key}' >"$payload"
AWS_PROFILE="$aws_profile" aws secretsmanager put-secret-value \
  --secret-id "$secret_name" --region "$aws_region" --secret-string "file://$payload" >/dev/null
echo "Stored the scoped GitHub App credential in the project pilot secret. No key material was printed."
