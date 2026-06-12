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
  description = "PostgreSQL master username (shared across all databases)"
  type        = string
  default     = "sathishadmin"
}
