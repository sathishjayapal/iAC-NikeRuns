variable "aws_region" {
  description = "AWS region for the ACG sandbox"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "sathish-shared"
}

variable "master_username" {
  description = "Aurora PostgreSQL master username"
  type        = string
  default     = "sathishadmin"
}

variable "enable_budget_guardrail" {
  description = "Create a budget guardrail that blocks DB access if cost threshold is exceeded"
  type        = bool
  default     = true
}

variable "monthly_budget_limit_usd" {
  description = "Monthly budget cap in USD before the guardrail triggers"
  type        = number
  default     = 10
}

variable "alert_email_addresses" {
  description = "Email addresses to notify on budget breach (must confirm SNS subscription)"
  type = list(string)
  default = []
}
