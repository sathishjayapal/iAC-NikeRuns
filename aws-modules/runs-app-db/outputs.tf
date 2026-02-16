output "cluster_id" {
  description = "Aurora cluster identifier"
  value       = aws_rds_cluster.this.cluster_identifier
}

output "cluster_arn" {
  description = "Aurora cluster ARN"
  value       = aws_rds_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Writer endpoint for Aurora PostgreSQL"
  value       = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Reader endpoint for Aurora PostgreSQL"
  value       = aws_rds_cluster.this.reader_endpoint
}

output "port" {
  description = "PostgreSQL port"
  value       = aws_rds_cluster.this.port
}

output "database_name" {
  description = "Initial database name"
  value       = aws_rds_cluster.this.database_name
}

output "security_group_id" {
  description = "Security group ID attached to the DB cluster"
  value       = aws_security_group.db.id
}

output "secret_arn" {
  description = "Secrets Manager ARN containing DB credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "budget_name" {
  description = "AWS Budget name used for DB cost guardrail"
  value       = var.enable_budget_guardrail ? aws_budgets_budget.db[0].name : null
}

output "budget_alerts_topic_arn" {
  description = "SNS topic ARN used for budget alerts"
  value       = var.enable_budget_guardrail ? aws_sns_topic.budget_alerts[0].arn : null
}

output "email_alert_subscriptions" {
  description = "Email addresses subscribed to budget alerts (require manual confirmation)"
  value       = var.enable_budget_guardrail ? var.alert_email_addresses : []
}
output "budget_shutdown_lambda_name" {
  description = "Lambda function name executed after budget threshold breach"
  value       = var.enable_budget_guardrail ? aws_lambda_function.budget_shutdown[0].function_name : null
}
