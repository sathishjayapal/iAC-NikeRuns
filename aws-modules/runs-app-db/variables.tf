variable "name_prefix" {
  description = "Prefix used for resource naming"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the database will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the Aurora subnet group (at least 2)"
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least two subnet IDs are required for Aurora."
  }
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks that can connect to PostgreSQL"
  type        = list(string)
  default     = []
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to connect to PostgreSQL"
  type        = list(string)
  default     = []
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "runsapp"
}

variable "master_username" {
  description = "Master database username"
  type        = string
  default     = "runsapp_admin"
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "16.4"
}

variable "db_port" {
  description = "Port exposed by Aurora PostgreSQL"
  type        = number
  default     = 5443

  validation {
    condition     = var.db_port >= 1024 && var.db_port <= 65535
    error_message = "db_port must be between 1024 and 65535."
  }
}

variable "min_acu" {
  description = "Minimum Aurora Serverless v2 capacity units"
  type        = number
  default     = 0.5
}

variable "max_acu" {
  description = "Maximum Aurora Serverless v2 capacity units"
  type        = number
  default     = 1
  validation {
    condition     = var.max_acu >= var.min_acu
    error_message = "max_acu must be greater than or equal to min_acu."
  }
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 3
}

variable "deletion_protection" {
  description = "Enable deletion protection on the DB cluster"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot when destroying DB cluster"
  type        = bool
  default     = false
}

variable "final_snapshot_identifier" {
  description = "Final snapshot identifier when skip_final_snapshot is false"
  type        = string
  default     = null

  validation {
    condition     = var.skip_final_snapshot || var.final_snapshot_identifier != null
    error_message = "final_snapshot_identifier must be set when skip_final_snapshot is false."
  }
}

variable "apply_immediately" {
  description = "Apply DB modifications immediately"
  type        = bool
  default     = true
}

variable "enable_budget_guardrail" {
  description = "Enable budget-based shutdown guardrail"
  type        = bool
  default     = true
}

variable "monthly_budget_limit_usd" {
  description = "Monthly budget threshold in USD"
  type        = number
  default     = 5
  validation {
    condition     = var.monthly_budget_limit_usd > 0
    error_message = "monthly_budget_limit_usd must be greater than 0."
  }
}

variable "budget_alert_threshold_percent" {
  description = "Budget alert threshold percentage"
  type        = number
  default     = 100
  validation {
    condition     = var.budget_alert_threshold_percent > 0
    error_message = "budget_alert_threshold_percent must be greater than 0."
  }
}

variable "shutdown_mode" {
  description = "Action when budget threshold is exceeded: stop_db or block_access"
  type        = string
  default     = "block_access"
  validation {
    condition     = contains(["stop_db", "block_access"], var.shutdown_mode)
    error_message = "shutdown_mode must be one of: stop_db, block_access."
  }
}

variable "budget_tag_key_value" {
  description = "Optional AWS Budget TagKeyValue filter (example: user:Project$runs-app)"
  type        = string
  default     = null
}

variable "alert_email_addresses" {
  description = "List of email addresses to receive budget alert notifications (in addition to Lambda shutdown)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
