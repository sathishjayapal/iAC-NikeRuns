resource "azurerm_service_plan" "sathish-appserviceplan" {
  name                = "sathish-appserviceplan"
  location            = azurerm_resource_group.rg_resource_defn.location
  resource_group_name = azurerm_resource_group.rg_resource_defn.name
  os_type             = var.appservice-ostype
  sku_name            = var.appservice-sku

}


resource "azurerm_linux_web_app" "sathishnikerunswebapp" {
  name                = "sathishnikerunswebapp"
  resource_group_name = azurerm_resource_group.rg_resource_defn.name
  location            = azurerm_service_plan.sathish-appserviceplan.location
  service_plan_id     = azurerm_service_plan.sathish-appserviceplan.id
  logs {
    application_logs {
      file_system_level = "Verbose"
    }
  }
  site_config {
    application_stack {
      docker_image     = var.dockerimagewithurl
      docker_image_tag = var.dockerimagetag
    }
    always_on = false
  }
}
