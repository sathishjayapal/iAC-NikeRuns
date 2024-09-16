output "postgresql_server_name" {
  description = "The name of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.sathishdb-server.name
}
output "postgresql_server_admin_login" {
  description = "The administrator login for the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.sathishdb-server.administrator_login
}

output "postgresql_server_version" {
  description = "The version of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.sathishdb-server.version
}

output "firewall_rule_start_ip" {
  description = "The start IP address of the firewall rule"
  value       = azurerm_postgresql_flexible_server_firewall_rule.sathishdbfw.start_ip_address
}

output "firewall_rule_end_ip" {
  description = "The end IP address of the firewall rule"
  value       = azurerm_postgresql_flexible_server_firewall_rule.sathishdbfw.end_ip_address
}
