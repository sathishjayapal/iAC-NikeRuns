##########################################################################
# Shared Aurora PostgreSQL — ACG Sandbox
#
# Architecture:
#   ┌─────────────────────────────────────────────────────────┐
#   │  VPC 10.0.0.0/16                                        │
#   │                                                          │
#   │  Public Subnets (10.0.1-3.0/24)                        │
#   │  ┌──────────────┐                                       │
#   │  │  SSM Relay   │  ← no SSH, no key pair               │
#   │  │  EC2 t3.micro│    IAM: AmazonSSMManagedInstanceCore  │
#   │  └──────┬───────┘                                       │
#   │         │  SG rule: port 5432 from SSM relay SG        │
#   │  Private Subnets (10.0.11-12.0/24)                     │
#   │  ┌──────▼───────────────────────────┐                  │
#   │  │  Aurora Serverless v2            │                   │
#   │  │  PostgreSQL 16                   │                   │
#   │  │  runsapp_db | event-service      │                   │
#   │  │  runs_ai_analyzer_db (pgvector)  │                   │
#   │  └──────────────────────────────────┘                   │
#   └─────────────────────────────────────────────────────────┘
#
# Your laptop connects via SSM port forwarding:
#   aws ssm start-session → SSM relay → Aurora:5432
#   Your app sees: localhost:5432 (no SSL needed)
#
# deletion_protection = false  }  safe for ACG sandbox teardown
# skip_final_snapshot = true   }
##########################################################################

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
  region = var.aws_region
  # For ACG: export env vars (do not use named profile — ACG rotates creds):
  #   export AWS_ACCESS_KEY_ID=...
  #   export AWS_SECRET_ACCESS_KEY=...
  #   export AWS_SESSION_TOKEN=...
}

##########################################################################
# VPC — fresh VPC, no default VPC dependency
##########################################################################

module "vpc" {
  source = "../vpc"

  region        = var.aws_region
  name_prefix   = var.name_prefix
  vpc_cidr      = "10.0.0.0/16"
  subnet01_cidr = "10.0.1.0/24"
  subnet02_cidr = "10.0.2.0/24"
  subnet03_cidr = "10.0.3.0/24"

  # Private subnets for Aurora — no internet route
  private_subnet01_cidr = "10.0.11.0/24"
  private_subnet02_cidr = "10.0.12.0/24"
}

##########################################################################
# SSM Relay EC2 — no bastion, no key pair, no port 22
#
# This is a tiny EC2 that lives in the public subnet and runs the
# AWS SSM agent. Your laptop connects to it via SSM (HTTPS/443 outbound
# from the EC2 to SSM endpoints), then SSM forwards traffic to Aurora.
#
# You never SSH into this box. It has no inbound rules at all.
# The DB security group allows port 5432 only from *this* instance's SG.
##########################################################################

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM role — only permission needed is SSM agent registration
resource "aws_iam_role" "ssm_relay" {
  name = "${var.name_prefix}-ssm-relay-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = { Name = "${var.name_prefix}-ssm-relay-role" }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_relay.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_relay" {
  name = "${var.name_prefix}-ssm-relay-profile"
  role = aws_iam_role.ssm_relay.name
}

# Security group — NO inbound rules at all.
# SSM agent makes outbound HTTPS connections to SSM endpoints.
resource "aws_security_group" "ssm_relay" {
  name        = "${var.name_prefix}-ssm-relay-sg"
  description = "SSM relay - outbound only, no inbound"
  vpc_id      = module.vpc.vpc_id

  egress {
    description = "Allow all outbound (SSM agent needs HTTPS to AWS endpoints)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-ssm-relay-sg" }
}

resource "aws_instance" "ssm_relay" {
  ami                  = data.aws_ami.amazon_linux_2023.id
  instance_type        = "t3.micro"
  subnet_id = module.vpc.subnet_ids[0]   # public subnet
  vpc_security_group_ids = [aws_security_group.ssm_relay.id]
  iam_instance_profile = aws_iam_instance_profile.ssm_relay.name
  associate_public_ip_address = true

  # SSM agent is pre-installed on AL2023 — no user_data needed

  tags = {
    Name      = "${var.name_prefix}-ssm-relay"
    Purpose   = "SSM port forwarding to Aurora — no SSH"
    ManagedBy = "terraform"
  }
}

##########################################################################
# Aurora Serverless v2 — in PRIVATE subnets
#
# runsapp_db is the initial database.
# event-service and runs_ai_analyzer_db are created post-apply
# by acg-aws-start.sh via the SSM tunnel.
##########################################################################

module "shared_db" {
  source = "../runs-app-db"

  name_prefix = var.name_prefix
  vpc_id      = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids   # ← private subnets

  db_name         = "runsapp_db"
  master_username = var.master_username
  db_port         = 5432

  engine_version = "16.4"   # PostgreSQL 16 — required for pgvector

  # Scale to zero when idle — keeps ACG costs near zero
  min_acu = 0.5
  max_acu = 2.0

  # Safe teardown for sandbox use
  deletion_protection = false
  skip_final_snapshot = true
  apply_immediately = true

  # Budget guardrail
  enable_budget_guardrail        = var.enable_budget_guardrail
  monthly_budget_limit_usd       = var.monthly_budget_limit_usd
  budget_alert_threshold_percent = 80
  shutdown_mode                  = "block_access"
  alert_email_addresses          = var.alert_email_addresses

  # Only allow connections from the SSM relay security group.
  # No CIDR ranges — even the VPC CIDR is not allowed directly.
  # This means nothing can reach Aurora except traffic forwarded
  # through the SSM relay instance.
  allowed_security_group_ids = [aws_security_group.ssm_relay.id]
  allowed_cidr_blocks = []

  tags = {
    Project     = "sathish-runs"
    Environment = "acg-sandbox"
    ManagedBy   = "terraform"
  }

  depends_on = [module.vpc]
}
