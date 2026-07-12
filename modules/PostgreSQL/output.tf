output "postgresql_server_name" {
  description = "The PostgreSQL server resource name"
  value       = azurerm_postgresql_flexible_server.sathishdb-server.name
}

output "postgresql_server_version" {
  description = "The PostgreSQL major version"
  value       = azurerm_postgresql_flexible_server.sathishdb-server.version
}

output "db_host" {
  description = "PostgreSQL server FQDN (use this in JDBC URLs)"
  value       = azurerm_postgresql_flexible_server.sathishdb-server.fqdn
}

output "db_port" {
  description = "PostgreSQL port — always 5432 on Azure Flexible Server"
  value       = 5432
}

output "db_admin_user" {
  description = "PostgreSQL administrator login"
  value       = azurerm_postgresql_flexible_server.sathishdb-server.administrator_login
}

output "db_admin_password" {
  description = "PostgreSQL administrator password"
  sensitive   = true
  value       = var.administrator_login_password
}

# ── Per-app JDBC connection strings (sslmode=require mandatory on Azure) ──────

output "jdbc_eventstracker" {
  description = "JDBC URL for eventstracker (event-service database)"
  sensitive   = true
  value       = "jdbc:postgresql://${azurerm_postgresql_flexible_server.sathishdb-server.fqdn}:5432/${azurerm_postgresql_flexible_server_database.eventstracker_db.name}?sslmode=require"
}

output "jdbc_runsapp" {
  description = "JDBC URL for runs-app (runsapp_db database)"
  sensitive   = true
  value       = "jdbc:postgresql://${azurerm_postgresql_flexible_server.sathishdb-server.fqdn}:5432/${azurerm_postgresql_flexible_server_database.runsapp_db.name}?sslmode=require"
}

output "jdbc_runsai" {
  description = "JDBC URL for runs-ai-analyzer (runs_ai_analyzer_db database)"
  sensitive   = true
  value       = "jdbc:postgresql://${azurerm_postgresql_flexible_server.sathishdb-server.fqdn}:5432/${azurerm_postgresql_flexible_server_database.runsai_db.name}?sslmode=require"
}

output "db_name_eventstracker" {
  value = azurerm_postgresql_flexible_server_database.eventstracker_db.name
}

output "db_name_runsapp" {
  value = azurerm_postgresql_flexible_server_database.runsapp_db.name
}

output "db_name_runsai" {
  value = azurerm_postgresql_flexible_server_database.runsai_db.name
}

output "jdbc_githubcleaner" {
  description = "JDBC URL for verbose-barnacle (my-github-cleaner database)"
  sensitive   = true
  value       = "jdbc:postgresql://${azurerm_postgresql_flexible_server.sathishdb-server.fqdn}:5432/${azurerm_postgresql_flexible_server_database.githubcleaner_db.name}?sslmode=require"
}

output "jdbc_dbcleaner" {
  description = "JDBC URL for dbcleaner (dbcleaner database)"
  sensitive   = true
  value       = "jdbc:postgresql://${azurerm_postgresql_flexible_server.sathishdb-server.fqdn}:5432/${azurerm_postgresql_flexible_server_database.dbcleaner_db.name}?sslmode=require"
}

output "db_name_githubcleaner" {
  value = azurerm_postgresql_flexible_server_database.githubcleaner_db.name
}

output "db_name_dbcleaner" {
  value = azurerm_postgresql_flexible_server_database.dbcleaner_db.name
}
