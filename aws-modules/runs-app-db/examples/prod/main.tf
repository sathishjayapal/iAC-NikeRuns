terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Data source to look up the VPC
data "aws_vpc" "existing" {
  id = "vpc-0f67b69c39640293b"  # Updated to the actual VPC ID from terraform state
}

# Data source to look up subnets in the VPC
data "aws_subnets" "database" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }

  # Optional: filter for specific subnets if needed (e.g., by tags or availability zones)
  # filter {
  #   name   = "tag:Name"
  #   values = ["*Subnet*"]
  # }
}

module "runs_app_db" {
  source                    = "../../"
  skip_final_snapshot       = false
  final_snapshot_identifier = "runs-app-prod-final-snapshot"
  name_prefix               = "runs-app-prod"
  vpc_id                    = data.aws_vpc.existing.id
  subnet_ids                = data.aws_subnets.database.ids

  # Prefer SG-based allow-listing for production workloads.
  allowed_security_group_ids = []

  db_port = 5443

  min_acu = 0.5
  max_acu = 1

  # Optional: Add email addresses to receive budget alert notifications
  # (in addition to automatic Lambda shutdown)
  # Subscribers will need to confirm their email subscription
  # alert_email_addresses = [
  #   "devops@example.com",
  #   "alerts@example.com"
  # ]
  enable_budget_guardrail        = true
  monthly_budget_limit_usd       = 5
  budget_alert_threshold_percent = 100
  shutdown_mode                  = "block_access"

  tags = {
    Environment = "prod"
    Project     = "runs-app"
    Owner       = "infrastructure"
  }
}
