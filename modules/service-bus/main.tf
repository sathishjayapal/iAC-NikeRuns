resource "azurerm_servicebus_namespace" "servicebus_namespace" {
  name                = join("", [var.prefix, var.main_group_name, "servicebus-namespace"])
  location            = var.primary_location
  resource_group_name = var.rg-name
  sku                 = "Standard"

  tags = {
    source = "terraform"
  }
}

resource "azurerm_servicebus_queue" "servicebus_namespace_queue" {
  name         = join("", [var.prefix, var.main_group_name, "servicebus"])
  namespace_id = azurerm_servicebus_namespace.servicebus_namespace.id
  partitioning_enabled = true
}
