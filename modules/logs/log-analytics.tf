resource "azurerm_log_analytics_workspace" "log_analytics_workspace" {
  name                = var.log_name
  location            = var.primary_location
  resource_group_name = var.rg_name
  retention_in_days   = var.log_retention_days
  sku                 = var.log_sku
}
output "log_analytics_workspace" {
  description = "ID of project log-analytics"
  sensitive   = true
  value       = azurerm_log_analytics_workspace.log_analytics_workspace
}

