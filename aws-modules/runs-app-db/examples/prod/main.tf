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

################################################################################
# VPC and Subnet Data Sources
#
# IMPORTANT: This example uses dynamic VPC lookup by tags instead of hardcoded
# IDs. This makes the code more flexible and prevents issues during cleanup.
#
# Benefits:
#  - VPC can be recreated without changing this code
#  - Works across multiple environments with same tags
#  - Easier cleanup with aws-nuke or terraform destroy
#
# For production, consider using:
#  - Remote state data sources
#  - Terraform variables for VPC ID
#  - Service discovery via tags
################################################################################

# Data source to look up the VPC by tags (more flexible than hardcoded ID)
# This allows the VPC to be recreated without changing this code
data "aws_vpc" "existing" {
  # Option 1: Look up by tag (recommended)
  tags = {
    Name = "sathish-eks-VPC"
  }

  # Option 2: Uncomment to use hardcoded ID instead (NOT RECOMMENDED)
  # id = "vpc-0f67b69c39640293b"

  # Option 3: Use variable (best for reusability)
  # id = var.vpc_id
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
