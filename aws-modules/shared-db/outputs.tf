output "ssm_relay_instance_id" {
  description = "EC2 instance ID of the SSM relay — used by acg-aws-start.sh for port forwarding"
  value       = aws_instance.ssm_relay.id
}

output "cluster_endpoint" {
  description = "Aurora writer endpoint — use in JDBC URLs"
  value       = module.shared_db.cluster_endpoint
}

output "cluster_port" {
  description = "PostgreSQL port"
  value       = module.shared_db.port
}

output "master_username" {
  description = "Aurora master username"
  value       = var.master_username
}

output "secret_arn" {
  description = "Secrets Manager ARN containing the DB password (username + password JSON)"
  value       = module.shared_db.secret_arn
}

output "cluster_id" {
  description = "Aurora cluster identifier"
  value       = module.shared_db.cluster_id
}

output "security_group_id" {
  description = "DB security group — add EKS node SG here if running apps on EKS"
  value       = module.shared_db.security_group_id
}

# ── JDBC URLs via SSM tunnel (localhost:5432) ─────────────────────────────────
# acg-aws-start.sh opens an SSM port-forwarding session so all apps
# connect to localhost:5432.  No SSL needed — traffic is inside the tunnel.
output "jdbc_runsapp" {
  description = "JDBC URL for runs-app (via SSM tunnel)"
  value       = "jdbc:postgresql://localhost:5432/runsapp_db"
}

output "jdbc_eventstracker" {
  description = "JDBC URL for eventstracker (via SSM tunnel)"
  value       = "jdbc:postgresql://localhost:5432/event-service"
}

output "jdbc_runsai" {
  description = "JDBC URL for runs-ai-analyzer (via SSM tunnel)"
  value       = "jdbc:postgresql://localhost:5432/runs_ai_analyzer_db"
}
