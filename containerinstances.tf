resource "random_string" "container_name" {
  length  = 5
  lower   = true
  upper   = false
  special = false
}

resource "azurerm_container_group" "container" {
  name                = "${var.base_name}-${random_string.container_name.result}"
  location            = var.primary_location
  resource_group_name = var.rg_name
  ip_address_type     = var.ip_address_type
  os_type             = var.os_type
  restart_policy      = var.restart_policy
  dns_name_label      = var.dns_name_label
  diagnostics {
    log_analytics {
      workspace_id  = azurerm_log_analytics_workspace.log_analytics_workspace.workspace_id
      workspace_key = azurerm_log_analytics_workspace.log_analytics_workspace.secondary_shared_key
    }
  }
  container {
    name   = "${var.base_name}-${random_string.container_name.result}"
    image  = var.image
    cpu    = var.cpu_cores
    memory = var.memory_in_gb

    ports {
      port     = var.port
      protocol = "TCP"
    }
  }
  depends_on = [
  azurerm_log_analytics_workspace.log_analytics_workspace]
}