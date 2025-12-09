# Example 1: Basic MSK Cluster with IAM Authentication
# This example shows a minimal configuration for a development environment

/*
module "msk_basic" {
  source = "./aws-modules/kafka"

  cluster_name = "dev-kafka-cluster"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.subnet_ids
  vpc_cidr     = "192.168.0.0/16"

  # Basic cluster configuration
  kafka_version          = "3.5.1"
  number_of_broker_nodes = 2
  broker_instance_type   = "kafka.m5.large"
  broker_volume_size     = 100

  # Security - IAM authentication with TLS
  encryption_in_transit_client_broker = "TLS"
  enable_iam_auth                     = true

  # Topic naming convention
  topic_naming_prefix          = "dev-"
  consumer_group_naming_prefix = "cg-dev-"

  # Logging
  enable_cloudwatch_logs        = true
  cloudwatch_log_retention_days = 7

  tags = {
    Environment = "development"
    ManagedBy   = "terraform"
  }
}
*/

# Example 2: Production MSK Cluster with High Availability
# This example shows a production-ready configuration with enhanced security

/*
module "msk_production" {
  source = "./aws-modules/kafka"

  cluster_name = "prod-kafka-cluster"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.subnet_ids
  vpc_cidr     = "192.168.0.0/16"

  # Production cluster configuration
  kafka_version          = "3.5.1"
  number_of_broker_nodes = 6  # 2 per AZ across 3 AZs
  broker_instance_type   = "kafka.m5.xlarge"
  broker_volume_size     = 500

  # Enhanced storage performance
  enable_provisioned_throughput = true
  volume_throughput            = 250

  # Security configuration
  encryption_in_transit_client_broker = "TLS"
  encryption_in_transit_in_cluster    = true
  kms_key_arn                        = aws_kms_key.msk.arn
  enable_iam_auth                    = true

  # Network security
  allowed_cidr_blocks          = "192.168.0.0/16"
  create_client_security_group = true

  # Comprehensive logging
  enable_cloudwatch_logs        = true
  cloudwatch_log_retention_days = 30
  enable_s3_logs               = true
  s3_logs_bucket               = "my-company-msk-logs"
  s3_logs_prefix               = "prod-kafka/"

  # Production Kafka settings
  auto_create_topics_enable   = false  # Prevent accidental topic creation
  default_replication_factor  = 3
  min_insync_replicas        = 2
  num_partitions             = 6

  # Topic naming convention - enforce company standards
  topic_naming_prefix          = "prod-"
  consumer_group_naming_prefix = "cg-prod-"

  # IAM roles for different applications
  create_producer_role = true
  create_consumer_role = true
  create_admin_role    = true

  producer_assume_role_arns = [
    "arn:aws:iam::123456789012:role/app-producer-role"
  ]

  consumer_assume_role_arns = [
    "arn:aws:iam::123456789012:role/app-consumer-role"
  ]

  admin_assume_role_arns = [
    "arn:aws:iam::123456789012:role/kafka-admin-role"
  ]

  tags = {
    Environment = "production"
    Project     = "data-platform"
    ManagedBy   = "terraform"
    CostCenter  = "engineering"
  }
}
*/

# Example 3: MSK Cluster with Multiple Authentication Methods
# This example shows how to enable both IAM and SCRAM authentication

/*
module "msk_multi_auth" {
  source = "./aws-modules/kafka"

  cluster_name = "multi-auth-kafka"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.subnet_ids
  vpc_cidr     = "192.168.0.0/16"

  kafka_version          = "3.5.1"
  number_of_broker_nodes = 3
  broker_instance_type   = "kafka.m5.large"

  # Enable multiple authentication methods
  encryption_in_transit_client_broker = "TLS"
  enable_iam_auth                     = true
  enable_scram_auth                   = true

  # Topic naming convention
  topic_naming_prefix          = "app-"
  consumer_group_naming_prefix = "cg-app-"

  tags = {
    Environment = "staging"
  }
}
*/

# Example 4: MSK Cluster with Monitoring Enabled
# This example shows how to enable JMX and Node exporters for monitoring

/*
module "msk_with_monitoring" {
  source = "./aws-modules/kafka"

  cluster_name = "monitored-kafka"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.subnet_ids
  vpc_cidr     = "192.168.0.0/16"

  kafka_version          = "3.5.1"
  number_of_broker_nodes = 3
  broker_instance_type   = "kafka.m5.large"

  # Security
  encryption_in_transit_client_broker = "TLS"
  enable_iam_auth                     = true

  # Enable monitoring exporters
  enable_jmx_exporter  = true
  enable_node_exporter = true

  # Logging to multiple destinations
  enable_cloudwatch_logs = true
  enable_s3_logs        = true
  s3_logs_bucket        = "monitoring-logs-bucket"

  # Topic naming
  topic_naming_prefix          = "metrics-"
  consumer_group_naming_prefix = "cg-metrics-"

  tags = {
    Environment = "monitoring"
    Purpose     = "metrics-collection"
  }
}
*/

# Example 5: Cost-Optimized Development Cluster
# This example shows a minimal configuration for development/testing

/*
module "msk_dev_minimal" {
  source = "./aws-modules/kafka"

  cluster_name = "dev-minimal-kafka"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = slice(module.vpc.subnet_ids, 0, 2)  # Only 2 subnets
  vpc_cidr     = "192.168.0.0/16"

  # Minimal configuration
  kafka_version          = "3.5.1"
  number_of_broker_nodes = 2  # Minimum for MSK
  broker_instance_type   = "kafka.t3.small"  # Smallest instance
  broker_volume_size     = 50  # Minimal storage

  # Basic security
  encryption_in_transit_client_broker = "TLS"
  enable_iam_auth                     = true

  # Minimal logging
  enable_cloudwatch_logs        = true
  cloudwatch_log_retention_days = 3  # Short retention

  # Kafka settings for development
  auto_create_topics_enable  = true  # Allow auto-creation in dev
  default_replication_factor = 2     # Lower replication
  min_insync_replicas       = 1      # Lower durability for dev

  # Simple naming
  topic_naming_prefix          = "dev-"
  consumer_group_naming_prefix = "cg-dev-"

  # Don't create separate IAM roles for dev
  create_producer_role = false
  create_consumer_role = false
  create_admin_role    = false

  tags = {
    Environment = "development"
    CostOptimized = "true"
  }
}
*/

# Example 6: Integration with Existing VPC Module
# This example shows how to integrate with the existing VPC module in this project

/*
# First, ensure VPC module is configured
module "vpc" {
  source = "./aws-modules/vpc"

  region         = "us-east-1"
  name_prefix    = "my-app"
  vpc_cidr       = "192.168.0.0/16"
  subnet01_cidr  = "192.168.64.0/18"
  subnet02_cidr  = "192.168.128.0/18"
  subnet03_cidr  = "192.168.192.0/18"
}

# Then create MSK cluster using VPC outputs
module "msk" {
  source = "./aws-modules/kafka"

  cluster_name = "my-app-kafka"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.subnet_ids
  vpc_cidr     = "192.168.0.0/16"

  kafka_version          = "3.5.1"
  number_of_broker_nodes = 3
  broker_instance_type   = "kafka.m5.large"

  encryption_in_transit_client_broker = "TLS"
  enable_iam_auth                     = true

  topic_naming_prefix          = "myapp-"
  consumer_group_naming_prefix = "cg-myapp-"

  tags = {
    Environment = "production"
    Project     = "my-app"
  }
}

# Output connection information
output "kafka_connection_info" {
  value = module.msk.connection_info
  sensitive = true
}
*/
