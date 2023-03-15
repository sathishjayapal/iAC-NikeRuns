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
locals {
  base_name = "sathish"
  rg_name   = "${local.base_name}_config_sever_rg"
}
resource "azurerm_resource_group" "rg_resource_defn" {
  location = "East US 2"
  name     = local.rg_name
}
resource "azurerm_storage_account" "storage_resource_defn" {
  account_replication_type = "LRS"
  account_tier             = "Standard"
  location                 = "East US 2"
  name                     = "sathishrunstorageaccount"
  resource_group_name      = local.rg_name
  account_kind             = "StorageV2"
  depends_on               = [
    azurerm_resource_group.rg_resource_defn
  ]
}
resource "azurerm_storage_container" "storage_container_defn" {
  name                  = "sathishrunblobcontainer"
  storage_account_name  = "sathishrunstorageaccount"
  container_access_type = "blob"
  depends_on            = [azurerm_storage_account.storage_resource_defn]
}
resource "azurerm_storage_blob" "storage_blob_defn" {
  name                   = "main.tf"
  storage_account_name   = "sathishrunstorageaccount"
  storage_container_name = "sathishrunblobcontainer"
  type                   = "Block"
  source                 = "main.tf"
  depends_on             = [azurerm_storage_container.storage_container_defn]
}

