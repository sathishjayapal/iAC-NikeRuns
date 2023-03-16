resource "azurerm_log_analytics_workspace" "log_analytics_workspace" {
  name                = "acctest-01"
  location            = local.location
  resource_group_name = local.rg_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  depends_on = [
    azurerm_storage_blob.storage_blob_defn
  ]
}
resource "azurerm_container_app_environment" "container_app_environment" {
  name                       = "${local.base_name}Environment"
  location                   = local.location
  resource_group_name        = local.rg_name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics_workspace.id
  depends_on = [
    azurerm_log_analytics_workspace.log_analytics_workspace
  ]
}
resource "azurerm_container_app" "container_app" {
  name                         = "${local.base_name}configservercontainerapp"
  container_app_environment_id = azurerm_container_app_environment.container_app_environment.id
  resource_group_name          = local.rg_name
  revision_mode                = "Single"

  template {
    container {
      name   = "${local.base_name}runsapp"
      image  = "dockerhub.io/sathishjatdot/sathishprojects_config_server:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }
}
