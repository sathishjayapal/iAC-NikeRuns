##########################################################################
# Shared PostgreSQL — ACG Sandbox
#
# NOTE: ACG SCP (p-cr6s9vs4) denies rds:CreateDBInstance, blocking ALL
# managed RDS options (Aurora Serverless v1 is end-of-life; v2 needs the
# blocked API). Solution: PostgreSQL 16 + pgvector in Docker on EC2.
#
# Architecture:
#   ┌─────────────────────────────────────────────────────────┐
#   │  VPC 10.0.0.0/16                                        │
#   │                                                          │
#   │  Public Subnet (10.0.1.0/24)                           │
#   │  ┌─────────────────────────────────────────────┐        │
#   │  │  EC2 t3.micro (SSM relay + DB host)         │        │
#   │  │  Docker: pgvector/pgvector:pg16              │        │
#   │  │  Three databases on 127.0.0.1:5432 only:    │        │
#   │  │    runsapp_db, event-service,               │        │
#   │  │    runs_ai_analyzer_db (+pgvector)           │        │
#   │  └─────────────────────────────────────────────┘        │
#   └─────────────────────────────────────────────────────────┘
#
# Laptop connects via SSM port forwarding (single tunnel):
#   aws ssm start-session (AWS-StartPortForwardingSession)
#   → EC2 port 5432 → PostgreSQL in Docker
#   All apps connect to: localhost:5432
##########################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
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

  private_subnet01_cidr = "10.0.11.0/24"
  private_subnet02_cidr = "10.0.12.0/24"
}

##########################################################################
# SSM Relay EC2 — no bastion, no key pair, no port 22
#
# Hosts all three PostgreSQL databases in a single Docker container.
# SSM agent makes outbound HTTPS connections so no inbound SG rules needed.
##########################################################################

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    # "al2023-ami-2*" excludes the "al2023-ami-minimal-*" variant, which
    # does not ship amazon-ssm-agent pre-installed/enabled.
    values = ["al2023-ami-2*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "ssm_relay" {
  name = "${var.name_prefix}-ssm-relay-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
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

# No inbound rules — SSM agent uses outbound HTTPS only.
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
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.ssm_relay.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_relay.name
  associate_public_ip_address = true

  # Wait for all three VPC endpoints before creating the EC2.
  # Individual resource references (not for_each) so the dependency set
  # is fully known at plan time — avoids "inconsistent final plan" error.
  depends_on = [
    aws_vpc_endpoint.ssm,
    aws_vpc_endpoint.ssmmessages,
    aws_vpc_endpoint.ec2messages,
  ]

  # Installs Docker, starts pgvector/pgvector:pg16, creates all three
  # databases, and enables the vector extension.
  # Runs asynchronously at first boot — takes ~3-5 min for image pull.
  # acg-aws-start.sh polls localhost:5432 until ready.
  user_data = base64encode(<<-USERDATA
    #!/bin/bash
    # Do NOT use set -e here. Each step is individually checked.
    # cloud-init marks cloud-final as FAILED if the script exits non-zero,
    # which hides all errors. We log everything and exit 0 so cloud-init
    # stays green while the real status is in /var/log/pg-setup.log.
    exec > /var/log/pg-setup.log 2>&1
    set -uo pipefail

    log() { echo "[$(date '+%T')] $*"; }
    ok()  { echo "[$(date '+%T')] OK: $*"; }
    err() { echo "[$(date '+%T')] ERR: $*"; }

    log "=== PostgreSQL setup started ==="

    log "Installing Docker..."
    if dnf install -y docker; then
      ok "Docker installed"
    else
      err "dnf install docker failed"
      exit 0
    fi

    log "Starting Docker daemon..."
    systemctl enable docker
    if systemctl start docker; then
      ok "Docker running"
    else
      err "Docker failed to start"
      exit 0
    fi

    log "Pulling pgvector/pgvector:pg16 (first boot: ~2-5 min)..."
    if docker pull pgvector/pgvector:pg16; then
      ok "Image pulled"
    else
      err "docker pull failed — check outbound internet from EC2"
      exit 0
    fi

    log "Starting postgres container..."
    docker rm -f postgres-all 2>/dev/null || true
    if docker run -d \
        --name postgres-all \
        --restart unless-stopped \
        -e POSTGRES_USER=${var.master_username} \
        -e POSTGRES_PASSWORD='${random_password.db.result}' \
        -e POSTGRES_DB=postgres \
        -p 127.0.0.1:5432:5432 \
        pgvector/pgvector:pg16; then
      ok "Container started"
    else
      err "docker run failed"
      exit 0
    fi

    log "Waiting for PostgreSQL to accept connections (up to 5 min)..."
    READY=0
    for i in $(seq 1 60); do
      if docker exec postgres-all pg_isready -U ${var.master_username} 2>/dev/null; then
        READY=1; ok "PostgreSQL ready after $((i * 5))s"; break
      fi
      sleep 5
    done
    if [ "$READY" -eq 0 ]; then
      err "PostgreSQL did not become ready within 5 min"
      exit 0
    fi

    log "Creating application databases..."
    docker exec postgres-all psql -U ${var.master_username} -d postgres \
      -c "CREATE DATABASE runsapp_db;"         2>&1 || true
    docker exec postgres-all psql -U ${var.master_username} -d postgres \
      -c 'CREATE DATABASE "event-service";'    2>&1 || true
    docker exec postgres-all psql -U ${var.master_username} -d postgres \
      -c "CREATE DATABASE runs_ai_analyzer_db;" 2>&1 || true

    log "Enabling pgvector extension..."
    docker exec postgres-all psql -U ${var.master_username} -d runs_ai_analyzer_db \
      -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>&1 || true

    log "=== Setup complete ==="
    exit 0
  USERDATA
  )

  tags = {
    Name      = "${var.name_prefix}-ssm-relay"
    Purpose   = "SSM relay + all PostgreSQL databases via Docker pgvector:pg16"
    ManagedBy = "terraform"
  }

  # user_data only runs on first boot — ignore changes to prevent
  # Terraform replacing the instance on re-plan, which causes the
  # "Provider produced inconsistent final plan" error on public_ip.
  lifecycle {
    ignore_changes = [user_data]
  }
}

##########################################################################
# VPC Interface Endpoints for SSM
#
# WHY: SSM agent on the EC2 must call three AWS API endpoints to register.
# Even with an internet gateway + public IP, ACG network policies may block
# outbound traffic to AWS service URLs. VPC Interface Endpoints route that
# traffic privately inside AWS (PrivateLink), bypassing any such restriction.
#
# These three endpoints are required for SSM to work:
#   ssm         — agent registration + Systems Manager API calls
#   ssmmessages — Session Manager interactive sessions + port forwarding
#   ec2messages — SSM agent ↔ EC2 messaging (required for older regions like us-east-1)
#
# ASSUMPTION: ACG allows ec2:CreateVpcEndpoint. If Terraform fails here
# with AccessDenied, SSM is fundamentally blocked in ACG and we need to
# switch to direct SSH tunnel (see README for fallback).
#
# Cost: ~$0.01/hour each = $0.03/hour total. Negligible for sandbox sessions.
##########################################################################

# Security group for the VPC endpoints.
# Endpoints are Interface type (ENIs in the subnet) — they need inbound 443
# from the EC2 security group to accept SSM agent connections.
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.name_prefix}-vpc-endpoints-sg"
  description = "Allow HTTPS from SSM relay EC2 to VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "HTTPS from SSM relay EC2"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ssm_relay.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-vpc-endpoints-sg" }
}

# Three individual endpoint resources instead of for_each.
# for_each causes "Provider produced inconsistent final plan" on the EC2's
# public_ip/public_dns because Terraform can't fully resolve the endpoint
# set at plan time. Individual resources are known at plan time.

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.vpc.subnet_ids[0]]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags = { Name = "${var.name_prefix}-endpoint-ssm" }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.vpc.subnet_ids[0]]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags = { Name = "${var.name_prefix}-endpoint-ssmmessages" }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.vpc.subnet_ids[0]]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags = { Name = "${var.name_prefix}-endpoint-ec2messages" }
}

##########################################################################
# Database credentials — single password for all databases
##########################################################################

resource "random_password" "db" {
  length           = 20
  override_special = "_-"
  special          = true
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.name_prefix}/postgres"
  recovery_window_in_days = 0
  tags                    = { Name = "${var.name_prefix}-db-secret" }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    engine   = "postgres"
    username = var.master_username
    password = random_password.db.result
    host     = "localhost"
    port     = 5432
    databases = ["runsapp_db", "event-service", "runs_ai_analyzer_db"]
  })
}
