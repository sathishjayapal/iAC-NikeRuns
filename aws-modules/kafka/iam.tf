# IAM Role for MSK Cluster
resource "aws_iam_role" "msk_cluster" {
  count = var.create_iam_role ? 1 : 0
  name  = "${var.cluster_name}-msk-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "kafka.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-msk-cluster-role"
    }
  )
}Than

# IAM Policy for MSK Cluster CloudWatch Logs
resource "aws_iam_role_policy" "msk_cloudwatch_logs" {
  count = var.create_iam_role && var.enable_cloudwatch_logs ? 1 : 0
  name  = "${var.cluster_name}-msk-cloudwatch-logs"
  role  = aws_iam_role.msk_cluster[0].id

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
        Resource = "arn:aws:logs:*:*:log-group:/aws/msk/*"
      }
    ]
  })
}

# IAM Role for Kafka Producers with Topic Naming Convention Enforcement
resource "aws_iam_role" "kafka_producer" {
  count = var.create_producer_role ? 1 : 0
  name  = "${var.cluster_name}-kafka-producer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = var.producer_assume_role_services
          AWS     = var.producer_assume_role_arns
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-kafka-producer-role"
    }
  )
}

# IAM Policy for Kafka Producers with Topic Naming Convention
resource "aws_iam_role_policy" "kafka_producer" {
  count = var.create_producer_role ? 1 : 0
  name  = "${var.cluster_name}-kafka-producer-policy"
  role  = aws_iam_role.kafka_producer[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster"
        ]
        Resource = aws_msk_cluster.this.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:CreateTopic",
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:WriteData",
          "kafka-cluster:DescribeTopicDynamicConfiguration"
        ]
        Resource = "arn:aws:kafka:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/${aws_msk_cluster.this.cluster_name}/*/${var.topic_naming_prefix}*"
        Condition = {
          StringLike = {
            "kafka-cluster:topicName" = "${var.topic_naming_prefix}*"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:DescribeGroup"
        ]
        Resource = "arn:aws:kafka:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:group/${aws_msk_cluster.this.cluster_name}/*/${var.consumer_group_naming_prefix}*"
      }
    ]
  })
}

# IAM Role for Kafka Consumers with Topic Naming Convention Enforcement
resource "aws_iam_role" "kafka_consumer" {
  count = var.create_consumer_role ? 1 : 0
  name  = "${var.cluster_name}-kafka-consumer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = var.consumer_assume_role_services
          AWS     = var.consumer_assume_role_arns
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-kafka-consumer-role"
    }
  )
}

# IAM Policy for Kafka Consumers with Topic Naming Convention
resource "aws_iam_role_policy" "kafka_consumer" {
  count = var.create_consumer_role ? 1 : 0
  name  = "${var.cluster_name}-kafka-consumer-policy"
  role  = aws_iam_role.kafka_consumer[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster"
        ]
        Resource = aws_msk_cluster.this.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:ReadData",
          "kafka-cluster:DescribeTopicDynamicConfiguration"
        ]
        Resource = "arn:aws:kafka:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/${aws_msk_cluster.this.cluster_name}/*/${var.topic_naming_prefix}*"
        Condition = {
          StringLike = {
            "kafka-cluster:topicName" = "${var.topic_naming_prefix}*"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:DescribeGroup",
          "kafka-cluster:AlterGroup"
        ]
        Resource = "arn:aws:kafka:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:group/${aws_msk_cluster.this.cluster_name}/*/${var.consumer_group_naming_prefix}*"
        Condition = {
          StringLike = {
            "kafka-cluster:groupName" = "${var.consumer_group_naming_prefix}*"
          }
        }
      }
    ]
  })
}

# IAM Role for Kafka Admin with Full Access (but still enforcing naming conventions)
resource "aws_iam_role" "kafka_admin" {
  count = var.create_admin_role ? 1 : 0
  name  = "${var.cluster_name}-kafka-admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = var.admin_assume_role_services
          AWS     = var.admin_assume_role_arns
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-kafka-admin-role"
    }
  )
}

# IAM Policy for Kafka Admin
resource "aws_iam_role_policy" "kafka_admin" {
  count = var.create_admin_role ? 1 : 0
  name  = "${var.cluster_name}-kafka-admin-policy"
  role  = aws_iam_role.kafka_admin[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:*"
        ]
        Resource = [
          aws_msk_cluster.this.arn,
          "arn:aws:kafka:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/${aws_msk_cluster.this.cluster_name}/*/*",
          "arn:aws:kafka:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:group/${aws_msk_cluster.this.cluster_name}/*/*"
        ]
      }
    ]
  })
}

# Data sources for current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
