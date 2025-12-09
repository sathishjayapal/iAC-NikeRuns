# MSK Cluster Outputs
output "cluster_arn" {
  description = "ARN of the MSK cluster"
  value       = aws_msk_cluster.this.arn
}

output "cluster_name" {
  description = "Name of the MSK cluster"
  value       = aws_msk_cluster.this.cluster_name
}

output "bootstrap_brokers" {
  description = "Plaintext connection host:port pairs"
  value       = aws_msk_cluster.this.bootstrap_brokers
}

output "bootstrap_brokers_tls" {
  description = "TLS connection host:port pairs"
  value       = aws_msk_cluster.this.bootstrap_brokers_tls
}

output "bootstrap_brokers_sasl_scram" {
  description = "SASL/SCRAM connection host:port pairs"
  value       = aws_msk_cluster.this.bootstrap_brokers_sasl_scram
}

output "bootstrap_brokers_sasl_iam" {
  description = "IAM authentication connection host:port pairs"
  value       = aws_msk_cluster.this.bootstrap_brokers_sasl_iam
}

output "zookeeper_connect_string" {
  description = "Zookeeper connection string"
  value       = aws_msk_cluster.this.zookeeper_connect_string
}

output "current_version" {
  description = "Current version of the MSK cluster"
  value       = aws_msk_cluster.this.current_version
}

# Security Group Outputs
output "security_group_id" {
  description = "ID of the MSK cluster security group"
  value       = aws_security_group.msk.id
}

output "security_group_arn" {
  description = "ARN of the MSK cluster security group"
  value       = aws_security_group.msk.arn
}

output "client_security_group_id" {
  description = "ID of the MSK client security group (if created)"
  value       = var.create_client_security_group ? aws_security_group.msk_clients[0].id : null
}

output "client_security_group_arn" {
  description = "ARN of the MSK client security group (if created)"
  value       = var.create_client_security_group ? aws_security_group.msk_clients[0].arn : null
}

# IAM Role Outputs
output "cluster_role_arn" {
  description = "ARN of the MSK cluster IAM role"
  value       = var.create_iam_role ? aws_iam_role.msk_cluster[0].arn : null
}

output "producer_role_arn" {
  description = "ARN of the Kafka producer IAM role"
  value       = var.create_producer_role ? aws_iam_role.kafka_producer[0].arn : null
}

output "producer_role_name" {
  description = "Name of the Kafka producer IAM role"
  value       = var.create_producer_role ? aws_iam_role.kafka_producer[0].name : null
}

output "consumer_role_arn" {
  description = "ARN of the Kafka consumer IAM role"
  value       = var.create_consumer_role ? aws_iam_role.kafka_consumer[0].arn : null
}

output "consumer_role_name" {
  description = "Name of the Kafka consumer IAM role"
  value       = var.create_consumer_role ? aws_iam_role.kafka_consumer[0].name : null
}

output "admin_role_arn" {
  description = "ARN of the Kafka admin IAM role"
  value       = var.create_admin_role ? aws_iam_role.kafka_admin[0].arn : null
}

output "admin_role_name" {
  description = "Name of the Kafka admin IAM role"
  value       = var.create_admin_role ? aws_iam_role.kafka_admin[0].name : null
}

# Configuration Outputs
output "configuration_arn" {
  description = "ARN of the MSK configuration"
  value       = aws_msk_configuration.this.arn
}

output "configuration_latest_revision" {
  description = "Latest revision of the MSK configuration"
  value       = aws_msk_configuration.this.latest_revision
}

# CloudWatch Log Group Output
output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for MSK logs"
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.msk[0].name : null
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for MSK logs"
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.msk[0].arn : null
}

# Topic Naming Convention
output "topic_naming_prefix" {
  description = "Required prefix for all Kafka topics"
  value       = var.topic_naming_prefix
}

output "consumer_group_naming_prefix" {
  description = "Required prefix for all consumer groups"
  value       = var.consumer_group_naming_prefix
}

# Connection Information
output "connection_info" {
  description = "Connection information for the MSK cluster"
  value = {
    cluster_arn                   = aws_msk_cluster.this.arn
    bootstrap_brokers_tls         = aws_msk_cluster.this.bootstrap_brokers_tls
    bootstrap_brokers_sasl_iam    = aws_msk_cluster.this.bootstrap_brokers_sasl_iam
    zookeeper_connect_string      = aws_msk_cluster.this.zookeeper_connect_string
    topic_naming_prefix           = var.topic_naming_prefix
    consumer_group_naming_prefix  = var.consumer_group_naming_prefix
  }
}
