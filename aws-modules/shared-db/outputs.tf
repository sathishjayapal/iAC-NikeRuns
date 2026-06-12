output "ssm_relay_instance_id" {
  description = "EC2 instance ID — SSM relay + all database host"
  value       = aws_instance.ssm_relay.id
}

output "master_username" {
  description = "Shared master username for all databases"
  value       = var.master_username
}

output "secret_arn" {
  description = "Secrets Manager ARN for all database credentials"
  value       = aws_secretsmanager_secret.db.arn
}

# ── JDBC URLs via single SSM tunnel (localhost:5432) ──────────────────────────
output "jdbc_runsapp" {
  description = "JDBC URL for runs-app"
  value       = "jdbc:postgresql://localhost:5432/runsapp_db"
}

output "jdbc_eventstracker" {
  description = "JDBC URL for eventstracker"
  value       = "jdbc:postgresql://localhost:5432/event-service"
}

output "jdbc_runsai" {
  description = "JDBC URL for runs-ai-analyzer (pgvector enabled)"
  value       = "jdbc:postgresql://localhost:5432/runs_ai_analyzer_db"
}
