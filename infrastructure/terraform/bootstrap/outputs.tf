output "state_bucket" {
  value       = aws_s3_bucket.terraform_state.bucket
  description = "Encrypted/versioned state bucket created for this repository's Terraform."
}

output "lock_table" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "DynamoDB table used to lock Terraform state."
}

output "monthly_budget_name" {
  value       = aws_budgets_budget.monthly_pilot.name
  description = "Monthly actual-cost alert budget; it is not an automatic hard-spend stop."
}
