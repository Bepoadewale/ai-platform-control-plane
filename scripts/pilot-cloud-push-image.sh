#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
aws_region="${AWS_REGION:-us-east-1}"
repository="${PILOT_ECR_REPOSITORY:-ai-platform-control-plane}"
image_tag="${PILOT_IMAGE_TAG:-pilot}"

command -v aws >/dev/null && command -v docker >/dev/null || {
  echo "AWS CLI and Docker are required." >&2; exit 1;
}
actual_account="$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || { echo "Unexpected AWS account." >&2; exit 1; }

registry="${expected_account}.dkr.ecr.${aws_region}.amazonaws.com"
image="${registry}/${repository}:${image_tag}"
AWS_PROFILE="$aws_profile" aws ecr get-login-password --region "$aws_region" | docker login --username AWS --password-stdin "$registry"
docker build --quiet --platform linux/amd64 -f "$project_root/control-plane/Dockerfile" -t "$image" "$project_root"
docker push --quiet "$image"
echo "$image"
