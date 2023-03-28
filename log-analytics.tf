resource "azurerm_log_analytics_workspace" "log_analytics_workspace" {
  name                = var.log_name
  location            = local.location
  resource_group_name = local.rg_name
  sku                 = var.log_sku
  retention_in_days   = var.log_retention_days
  depends_on = [
    azurerm_resource_group.rg_resource_defn
  ]
}
output "log_analytics_workspace" {
  description = "ID of project VPC"
  sensitive   = true
  value       = azurerm_log_analytics_workspace.log_analytics_workspace
}
