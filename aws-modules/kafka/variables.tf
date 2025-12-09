# Required Variables
variable "cluster_name" {
  description = "Name of the MSK cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the MSK cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the MSK cluster (must be in at least 2 different AZs)"
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnet IDs are required for MSK cluster deployment."
  }
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC (used for security group rules)"
  type        = string
}

# Cluster Configuration
variable "kafka_version" {
  description = "Kafka version for the MSK cluster"
  type        = string
  default     = "3.5.1"
}

variable "number_of_broker_nodes" {
  description = "Number of broker nodes in the cluster (must be a multiple of the number of AZs)"
  type        = number
  default     = 3
  validation {
    condition     = var.number_of_broker_nodes >= 2
    error_message = "Number of broker nodes must be at least 2."
  }
}

variable "broker_instance_type" {
  description = "Instance type for Kafka brokers"
  type        = string
  default     = "kafka.m5.large"
}

variable "broker_volume_size" {
  description = "Size of the EBS volume for each broker (in GB)"
  type        = number
  default     = 100
}

variable "enable_provisioned_throughput" {
  description = "Enable provisioned throughput for EBS volumes"
  type        = bool
  default     = false
}

variable "volume_throughput" {
  description = "Provisioned throughput in MiB/s (only used if enable_provisioned_throughput is true)"
  type        = number
  default     = 250
}

# Security Configuration
variable "encryption_in_transit_client_broker" {
  description = "Encryption setting for data in transit between clients and brokers (TLS, TLS_PLAINTEXT, or PLAINTEXT)"
  type        = string
  default     = "TLS"
  validation {
    condition     = contains(["TLS", "TLS_PLAINTEXT", "PLAINTEXT"], var.encryption_in_transit_client_broker)
    error_message = "Must be one of: TLS, TLS_PLAINTEXT, or PLAINTEXT."
  }
}

variable "encryption_in_transit_in_cluster" {
  description = "Enable encryption for data in transit within the cluster"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encryption at rest (uses AWS managed key if not specified)"
  type        = string
  default     = null
}

variable "enable_iam_auth" {
  description = "Enable IAM authentication for the cluster"
  type        = bool
  default     = true
}

variable "enable_scram_auth" {
  description = "Enable SASL/SCRAM authentication for the cluster"
  type        = bool
  default     = false
}

variable "tls_certificate_authority_arns" {
  description = "List of ACM Certificate Authority ARNs for TLS client authentication"
  type        = list(string)
  default     = []
}

# Network Security
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to the MSK cluster (defaults to VPC CIDR if not specified)"
  type        = string
  default     = null
}

variable "create_client_security_group" {
  description = "Create a separate security group for client applications"
  type        = bool
  default     = true
}

variable "enable_jmx_exporter" {
  description = "Enable JMX Exporter for monitoring"
  type        = bool
  default     = false
}

variable "enable_node_exporter" {
  description = "Enable Node Exporter for monitoring"
  type        = bool
  default     = false
}

# Logging Configuration
variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs for broker logs"
  type        = bool
  default     = true
}

variable "cloudwatch_log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 7
}

variable "enable_firehose_logs" {
  description = "Enable Kinesis Data Firehose for broker logs"
  type        = bool
  default     = false
}

variable "firehose_delivery_stream" {
  description = "Name of the Kinesis Data Firehose delivery stream"
  type        = string
  default     = null
}

variable "enable_s3_logs" {
  description = "Enable S3 for broker logs"
  type        = bool
  default     = false
}

variable "s3_logs_bucket" {
  description = "Name of the S3 bucket for broker logs"
  type        = string
  default     = null
}

variable "s3_logs_prefix" {
  description = "Prefix for S3 broker logs"
  type        = string
  default     = "msk-logs/"
}

# Kafka Configuration
variable "auto_create_topics_enable" {
  description = "Enable auto creation of topics"
  type        = bool
  default     = false
}

variable "default_replication_factor" {
  description = "Default replication factor for topics"
  type        = number
  default     = 3
}

variable "min_insync_replicas" {
  description = "Minimum number of in-sync replicas"
  type        = number
  default     = 2
}

variable "num_io_threads" {
  description = "Number of I/O threads"
  type        = number
  default     = 8
}

variable "num_network_threads" {
  description = "Number of network threads"
  type        = number
  default     = 5
}

variable "num_partitions" {
  description = "Default number of partitions per topic"
  type        = number
  default     = 3
}

variable "num_replica_fetchers" {
  description = "Number of replica fetcher threads"
  type        = number
  default     = 2
}

variable "socket_receive_buffer_bytes" {
  description = "Socket receive buffer size in bytes"
  type        = number
  default     = 102400
}

variable "socket_request_max_bytes" {
  description = "Maximum size of a request in bytes"
  type        = number
  default     = 104857600
}

variable "socket_send_buffer_bytes" {
  description = "Socket send buffer size in bytes"
  type        = number
  default     = 102400
}

variable "unclean_leader_election_enable" {
  description = "Enable unclean leader election"
  type        = bool
  default     = false
}

variable "zookeeper_session_timeout_ms" {
  description = "Zookeeper session timeout in milliseconds"
  type        = number
  default     = 18000
}

# Topic Naming Convention
variable "topic_naming_prefix" {
  description = "Required prefix for all Kafka topics (enforced via IAM policies)"
  type        = string
  default     = "app-"
  validation {
    condition     = length(var.topic_naming_prefix) > 0
    error_message = "Topic naming prefix cannot be empty."
  }
}

variable "consumer_group_naming_prefix" {
  description = "Required prefix for all consumer groups (enforced via IAM policies)"
  type        = string
  default     = "cg-"
  validation {
    condition     = length(var.consumer_group_naming_prefix) > 0
    error_message = "Consumer group naming prefix cannot be empty."
  }
}

# IAM Configuration
variable "create_iam_role" {
  description = "Create IAM role for MSK cluster"
  type        = bool
  default     = true
}

variable "create_producer_role" {
  description = "Create IAM role for Kafka producers"
  type        = bool
  default     = true
}

variable "create_consumer_role" {
  description = "Create IAM role for Kafka consumers"
  type        = bool
  default     = true
}

variable "create_admin_role" {
  description = "Create IAM role for Kafka administrators"
  type        = bool
  default     = true
}

variable "producer_assume_role_services" {
  description = "AWS services that can assume the producer role"
  type        = list(string)
  default     = ["ec2.amazonaws.com", "ecs-tasks.amazonaws.com", "lambda.amazonaws.com"]
}

variable "producer_assume_role_arns" {
  description = "AWS ARNs (users/roles) that can assume the producer role"
  type        = list(string)
  default     = []
}

variable "consumer_assume_role_services" {
  description = "AWS services that can assume the consumer role"
  type        = list(string)
  default     = ["ec2.amazonaws.com", "ecs-tasks.amazonaws.com", "lambda.amazonaws.com"]
}

variable "consumer_assume_role_arns" {
  description = "AWS ARNs (users/roles) that can assume the consumer role"
  type        = list(string)
  default     = []
}

variable "admin_assume_role_services" {
  description = "AWS services that can assume the admin role"
  type        = list(string)
  default     = ["ec2.amazonaws.com"]
}

variable "admin_assume_role_arns" {
  description = "AWS ARNs (users/roles) that can assume the admin role"
  type        = list(string)
  default     = []
}

# Tags
variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
