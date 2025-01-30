resource "azurerm_eventgrid_namespace" "eventgridnamespace" {
  name                = join("", [var.prefix, var.main_group_name, "namespace"])
  location            = var.primary_location
  resource_group_name = var.rg-name

    sku                 = "Standard"
  tags = {
    environment = "Production"
  }
}

resource "azurerm_storage_account" "eventgridsa" {
  name                = join("", [var.prefix, var.main_group_name, "eventgrid"])
  resource_group_name      = var.rg-name
  location                 = var.primary_location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "staging"
  }
}

resource "azurerm_eventgrid_system_topic" "eventgridevtgrid" {
  name                   = "garminruns-topic"
  resource_group_name    = var.rg-name
  location               = var.primary_location
  source_arm_resource_id = azurerm_storage_account.eventgridsa.id
  topic_type             = "Microsoft.Storage.StorageAccounts"
}

