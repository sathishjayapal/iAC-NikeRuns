terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.8.0"
    }
  }
}
provider "azurerm" {
  subscription_id = ""
  tenant_id       = ""
  client_id       = ""
  features {}
}
resource "azurerm_resource_group" "my-rg-test-donot-delete" {
  location = "East US 2"
  name     = "my-rg-test-donot-delete"
}
resource "azurerm_storage_account" "nikerunstorage" {
  account_replication_type = "LRS"
  account_tier             = "Standard"
  location                 = "East US 2"
  name                     = "nikerunstorage"
  resource_group_name      = "my-rg-test-donot-delete"
  account_kind             = "StorageV2"
}
resource "azurerm_storage_container" "nikerunsjsondata" {
  container_access_type = "blob"
  name                  = "nikejsondata"
  storage_account_name  = "nikerunstorage"
}
resource "azurerm_storage_blob" "nikerunsdatajson11" {
  name                   = "nikerunsdatajson11"
  storage_account_name   = "nikerunstorage"
  storage_container_name = "nikerunsjsondata"
  type                   = "Block"
  source                 = "activities-11.json"
}
