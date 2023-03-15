terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.8.0"
    }
  }
}
provider "azurerm" {
  subscription_id = "b43c969f-b5f5-42ce-a1f3-57886e9935b2"
  tenant_id       = "3c44a19d-2993-4b1d-868e-3c7bcf63bc60"
  client_id       = ""
  features {}
}
locals {
  base_name   = "sathish"
  rg_name     = "${local.base_name}_config_sever_rg"
  region_name = "East US 2"
}
resource "azurerm_resource_group" "rg_resource_defn" {
  location = local.region_name
  name     = local.rg_name
}
resource "azurerm_storage_account" "storage_resource_defn" {
  account_replication_type = "LRS"
  account_tier             = "Standard"
  location                 = local.region_name
  name                     = "sathishrunstorageaccount"
  resource_group_name      = local.rg_name
  account_kind             = "StorageV2"
  depends_on = [
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

