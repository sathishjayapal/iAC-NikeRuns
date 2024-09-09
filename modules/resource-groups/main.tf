resource "azurerm_resource_group" "rg_resource_defn" {
  location = var.primary_location
  name     = var.rg_name
  timeouts {
    create = var.timeout_min
    delete = var.timeout_delete
  }
}
