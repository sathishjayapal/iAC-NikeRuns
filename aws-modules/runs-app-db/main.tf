################################################################################
# Locals: Configuration values used throughout the module
################################################################################
locals {
  # Cluster identifier for Aurora PostgreSQL database
  cluster_identifier = "${var.name_prefix}-aurora-pg"

  # Base tags applied to all resources for consistency and organization
  base_tags = merge(
    {
      Name      = local.cluster_identifier
      Project   = "runs-app"
      ManagedBy = "terraform"
    },
    var.tags
  )

  # Cost filter values for budget alerts - includes RDS service and optional budget tag key-value pair
  budget_cost_filter_values = var.budget_tag_key_value == null ? ["Amazon Relational Database Service"] : ["Amazon Relational Database Service", var.budget_tag_key_value]
}

################################################################################
# Password Management
################################################################################

# Generate a secure random password for the Aurora database master user
# Length: 24 characters with special characters for strong security
resource "random_password" "master" {
  length           = 24
  override_special = "_-%@"
  special          = true
}

################################################################################
# Database Networking
################################################################################

# Create a DB subnet group for Aurora cluster placement across specified subnets
# This enables multi-AZ deployment for high availability
resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db-subnets"
  subnet_ids = var.subnet_ids

  tags = merge(
    local.base_tags,
    {
      Name = "${var.name_prefix}-db-subnets"
    }
  )
}

################################################################################
# Security Group Configuration
################################################################################

# Security group for Aurora database cluster
# Controls inbound and outbound traffic to the database
resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-db-sg"
  description = "Access controls for runs-app Aurora PostgreSQL"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.base_tags,
    {
      Name = "${var.name_prefix}-db-sg"
    }
  )
}

# Ingress rules allowing PostgreSQL access from specified CIDR blocks
# Enables database access from specific network ranges
resource "aws_vpc_security_group_ingress_rule" "cidr" {
  for_each = toset(var.allowed_cidr_blocks)

  security_group_id = aws_security_group.db.id
  ip_protocol       = "tcp"
  from_port         = var.db_port
  to_port           = var.db_port
  cidr_ipv4         = each.value
  description       = "PostgreSQL ${var.db_port} from ${each.value}"
}

# Ingress rules allowing PostgreSQL access from specified security groups
# Enables database access from other AWS resources via security group association
resource "aws_vpc_security_group_ingress_rule" "source_sg" {
  for_each = toset(var.allowed_security_group_ids)

  security_group_id            = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
  referenced_security_group_id = each.value
  description                  = "PostgreSQL ${var.db_port} from security group ${each.value}"
}

################################################################################
# Aurora PostgreSQL Database Cluster
################################################################################

# Aurora PostgreSQL cluster with serverless v2 scaling
# Provides auto-scaling database capacity based on workload demand
# Features:
#  - Encryption at rest enabled
#  - Automated backups with configurable retention
#  - CloudWatch log export for PostgreSQL logs
#  - Storage encrypted for data at rest
#  - Multi-AZ support for high availability
resource "aws_rds_cluster" "this" {
  cluster_identifier                  = local.cluster_identifier
  engine                              = "aurora-postgresql"
  engine_version                      = var.engine_version
  engine_mode                         = "provisioned"
  db_subnet_group_name                = aws_db_subnet_group.this.name
  vpc_security_group_ids              = [aws_security_group.db.id]
  database_name                       = var.db_name
  master_username                     = var.master_username
  master_password                     = random_password.master.result
  port                                = var.db_port
  backup_retention_period             = var.backup_retention_period
  storage_encrypted                   = true
  copy_tags_to_snapshot               = true
  deletion_protection                 = var.deletion_protection
  skip_final_snapshot                 = var.skip_final_snapshot
  final_snapshot_identifier           = var.skip_final_snapshot ? null : var.final_snapshot_identifier
  apply_immediately                   = var.apply_immediately
  enabled_cloudwatch_logs_exports     = ["postgresql"]
  iam_database_authentication_enabled = false

  serverlessv2_scaling_configuration {
    min_capacity = var.min_acu
    max_capacity = var.max_acu
  }

  tags = local.base_tags
}

# Aurora database instance - the primary (writer) instance in the cluster
# Handles all read and write operations
# Uses serverless compute for automatic scaling
resource "aws_rds_cluster_instance" "writer" {
  identifier           = "${var.name_prefix}-writer-1"
  cluster_identifier   = aws_rds_cluster.this.id
  instance_class       = "db.serverless"
  engine               = aws_rds_cluster.this.engine
  engine_version       = aws_rds_cluster.this.engine_version
  db_subnet_group_name = aws_db_subnet_group.this.name
  publicly_accessible  = false
  apply_immediately    = var.apply_immediately

  tags = merge(
    local.base_tags,
    {
      Name = "${var.name_prefix}-writer-1"
    }
  )
}

################################################################################
# Secrets Management
################################################################################

# AWS Secrets Manager secret for storing database credentials
# Stores PostgreSQL connection details in encrypted format
# With recovery_window_in_days = 0, deletion is immediate (no recovery window)
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.name_prefix}/runs-app/postgres"
  recovery_window_in_days = 0

  tags = local.base_tags
}

# Secret version containing the actual database credentials
# Stores connection details in JSON format:
#  - engine: "postgres" database engine type
#  - username: Master user username
#  - password: Randomly generated secure password
#  - dbname: Database name
#  - port: PostgreSQL port
#  - host: RDS cluster endpoint
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    engine   = "postgres"
    username = var.master_username
    password = random_password.master.result
    dbname   = var.db_name
    port     = var.db_port
    host     = aws_rds_cluster.this.endpoint
  })
}

################################################################################
# Budget Guardrail Setup
################################################################################

# Retrieve current AWS account ID for use in policies
data "aws_caller_identity" "current" {}

# SNS topic for budget alert notifications
# Only created if enable_budget_guardrail is true
# Receives notifications from AWS Budgets when budget thresholds are exceeded
resource "aws_sns_topic" "budget_alerts" {
  count = var.enable_budget_guardrail ? 1 : 0
  name  = "${var.name_prefix}-db-budget-alerts"

  tags = local.base_tags
}

# IAM policy document allowing AWS Budgets service to publish to SNS topic
# Includes condition to restrict access to current AWS account only
data "aws_iam_policy_document" "budget_sns" {
  count = var.enable_budget_guardrail ? 1 : 0

  statement {
    sid    = "AllowBudgetsPublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }

    actions = ["SNS:Publish"]

    resources = [aws_sns_topic.budget_alerts[0].arn]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

# Attaches the SNS policy to allow AWS Budgets to publish budget notifications
resource "aws_sns_topic_policy" "budget_alerts" {
  count = var.enable_budget_guardrail ? 1 : 0
  arn   = aws_sns_topic.budget_alerts[0].arn

  policy = data.aws_iam_policy_document.budget_sns[0].json
}

# Archive file containing the Lambda function code for budget enforcement
# Creates a zip archive with Python code that either stops the database cluster
# or blocks access via security group rules when budget threshold is exceeded
data "archive_file" "budget_shutdown_lambda" {
  count       = var.enable_budget_guardrail ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/${var.name_prefix}-budget-shutdown.zip"

  source {
    filename = "index.py"
    content  = <<-PY
import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

rds = boto3.client("rds")
ec2 = boto3.client("ec2")



def _stop_db(cluster_identifier: str):
    logger.info("Stopping DB cluster %s", cluster_identifier)
    rds.stop_db_cluster(DBClusterIdentifier=cluster_identifier)



def _block_access(security_group_id: str):
    logger.info("Revoking ingress rules for security group %s", security_group_id)
    response = ec2.describe_security_groups(GroupIds=[security_group_id])
    ingress_rules = response["SecurityGroups"][0].get("IpPermissions", [])

    if ingress_rules:
        ec2.revoke_security_group_ingress(GroupId=security_group_id, IpPermissions=ingress_rules)



def handler(event, context):
    logger.info("Received event: %s", json.dumps(event))

    shutdown_mode = os.environ["SHUTDOWN_MODE"]
    cluster_identifier = os.environ["CLUSTER_IDENTIFIER"]
    security_group_id = os.environ["SECURITY_GROUP_ID"]

    if shutdown_mode == "stop_db":
        _stop_db(cluster_identifier)
    elif shutdown_mode == "block_access":
        _block_access(security_group_id)
    else:
        raise ValueError(f"Unsupported shutdown mode: {shutdown_mode}")

    return {"status": "ok", "shutdown_mode": shutdown_mode}
PY
  }
}

# IAM role for the budget enforcement Lambda function
# Allows Lambda to assume role and execute
resource "aws_iam_role" "budget_shutdown_lambda" {
  count = var.enable_budget_guardrail ? 1 : 0

  name = "${var.name_prefix}-budget-shutdown-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.base_tags
}

# IAM policy for Lambda function permissions
# Grants permissions to:
#  - Create CloudWatch logs
#  - Stop RDS database cluster
#  - Describe and revoke security group ingress rules
resource "aws_iam_role_policy" "budget_shutdown_lambda" {
  count = var.enable_budget_guardrail ? 1 : 0

  name = "${var.name_prefix}-budget-shutdown-lambda-policy"
  role = aws_iam_role.budget_shutdown_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds:StopDBCluster"
        ]
        Resource = aws_rds_cluster.this.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeSecurityGroups",
          "ec2:RevokeSecurityGroupIngress"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda function for enforcing budget limits
# Triggered by SNS when budget threshold is exceeded
# Can either stop the database or block access based on shutdown_mode variable
resource "aws_lambda_function" "budget_shutdown" {
  count = var.enable_budget_guardrail ? 1 : 0

  function_name = "${var.name_prefix}-budget-shutdown"
  role          = aws_iam_role.budget_shutdown_lambda[0].arn
  runtime       = "python3.12"
  handler       = "index.handler"
  filename      = data.archive_file.budget_shutdown_lambda[0].output_path

  source_code_hash = data.archive_file.budget_shutdown_lambda[0].output_base64sha256
  timeout          = 60

  environment {
    variables = {
      SHUTDOWN_MODE      = var.shutdown_mode
      CLUSTER_IDENTIFIER = aws_rds_cluster.this.cluster_identifier
      SECURITY_GROUP_ID  = aws_security_group.db.id
    }
  }

  tags = local.base_tags
}

# SNS subscription connecting budget alerts to Lambda function
# Triggers Lambda execution when budget threshold notification is received
resource "aws_sns_topic_subscription" "budget_shutdown_lambda" {
  count = var.enable_budget_guardrail ? 1 : 0

  topic_arn = aws_sns_topic.budget_alerts[0].arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.budget_shutdown[0].arn
}

# Lambda permission allowing SNS to invoke the budget shutdown function
# Required for SNS to trigger Lambda execution
resource "aws_lambda_permission" "budget_shutdown_sns" {
  count = var.enable_budget_guardrail ? 1 : 0

  statement_id  = "AllowExecutionFromBudgetSns"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.budget_shutdown[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.budget_alerts[0].arn
}

# Email subscriptions for budget alert notifications
# Sends emails to specified addresses when budget threshold is exceeded
# Only created if enable_budget_guardrail is true
resource "aws_sns_topic_subscription" "budget_email_alerts" {
  for_each = var.enable_budget_guardrail ? toset(var.alert_email_addresses) : toset([])

  topic_arn = aws_sns_topic.budget_alerts[0].arn
  protocol  = "email"
  endpoint  = each.value
}

# AWS Budgets configuration for monitoring RDS costs
# Monitors monthly costs and triggers alerts when threshold percentage is exceeded
# Cost filtering can be applied by service and/or custom budget tags
resource "aws_budgets_budget" "db" {
  count = var.enable_budget_guardrail ? 1 : 0

  name         = "${var.name_prefix}-runs-app-db-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "cost_filter" {
    for_each = local.budget_cost_filter_values
    content {
      name   = cost_filter.value == "Amazon Relational Database Service" ? "Service" : "TagKeyValue"
      values = [cost_filter.value]
    }
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = var.budget_alert_threshold_percent
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.budget_alerts[0].arn]
  }

  depends_on = [
    aws_sns_topic_policy.budget_alerts,
    aws_sns_topic_subscription.budget_shutdown_lambda,
    aws_lambda_permission.budget_shutdown_sns
  ]
}
