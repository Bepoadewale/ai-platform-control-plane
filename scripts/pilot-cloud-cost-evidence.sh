#!/usr/bin/env bash
set -euo pipefail

# Cost Explorer is eventually consistent. This records its current response without pretending the
# same-day result is final billing evidence. The pilot uses Terraform project tags and a USD 10
# budget as immediate controls; rerun after AWS publishes daily usage for measured evidence.
aws_profile="${AWS_PROFILE:-ai-platform-pilot-key}"
aws_region="${AWS_REGION:-us-east-1}"
expected_account="${EXPECTED_AWS_ACCOUNT_ID:-654654474502}"
start_date="${PILOT_COST_START_DATE:-$(date -u -v-2d +%F 2>/dev/null || date -u -d '2 days ago' +%F)}"
end_date="${PILOT_COST_END_DATE:-$(date -u +%F)}"
actual_account="$(AWS_PROFILE="$aws_profile" aws sts get-caller-identity --query Account --output text)"
[[ "$actual_account" == "$expected_account" ]] || { echo "Unexpected AWS account." >&2; exit 1; }

AWS_PROFILE="$aws_profile" aws ce get-cost-and-usage --region "$aws_region" \
  --time-period Start="$start_date",End="$end_date" \
  --granularity DAILY --metrics UnblendedCost \
  --filter '{"Tags":{"Key":"project","Values":["ai-platform-control-plane"]}}' \
  --output json
echo "Cost Explorer query completed for $start_date through $end_date. AWS can delay daily usage by 24-48 hours; an empty or partial result is not a zero-cost claim."
