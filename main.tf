locals {
  base_name = "sathish"
  rg_name   = "${local.base_name}_config_sever_rg"
  location  = "East US 2"
}
resource "azurerm_resource_group" "rg_resource_defn" {
  location = local.location
  name     = local.rg_name
}
resource "azurerm_storage_account" "storage_resource_defn" {
  account_replication_type = "LRS"
  account_tier             = "Standard"
  location                 = local.location
  name                     = "${local.base_name}runstorageaccount"
  resource_group_name      = local.rg_name
  account_kind             = "StorageV2"
  depends_on = [
    azurerm_resource_group.rg_resource_defn
  ]
}
resource "azurerm_storage_container" "storage_container_defn" {
  name                  = "${local.base_name}runblobcontainer"
  storage_account_name  = "${local.base_name}runstorageaccount"
  container_access_type = "blob"
  depends_on            = [azurerm_storage_account.storage_resource_defn]
}
resource "azurerm_storage_blob" "storage_blob_defn" {
  name                   = "main.tf"
  storage_account_name   = "${local.base_name}runstorageaccount"
  storage_container_name = "${local.base_name}blobcontainer"
  type                   = "Block"
  source                 = "main.tf"
  depends_on             = [azurerm_storage_container.storage_container_defn]
}

