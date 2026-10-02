variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Single approved pilot region."
}

variable "expected_account_id" {
  type        = string
  description = "Account allowed to receive the pilot guardrails."
}

variable "budget_alert_email" {
  type        = string
  sensitive   = true
  description = "Recipient for monthly actual-cost budget alerts; never commit this value."
}

variable "monthly_budget_usd" {
  type        = number
  default     = 10
  description = "Pilot monthly actual-cost alert threshold. AWS Budgets is alerting, not a spend guarantee."

  validation {
    condition     = var.monthly_budget_usd > 0 && var.monthly_budget_usd <= 10
    error_message = "The initial pilot budget must be greater than zero and no more than USD 10."
  }
}

variable "project" {
  type        = string
  default     = "ai-platform-control-plane"
  description = "Project-scoped prefix used for resources and mandatory tags."
}
