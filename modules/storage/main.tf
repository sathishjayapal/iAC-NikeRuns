
# end of stroage account attributes

# Define the storage account
resource "azurerm_storage_account" "storage_account" {
  name                     = join("", [var.prefix, var.main_group_name, "storaccnt"])
  resource_group_name      = var.rg-name
  location                 = var.primary_location
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type
  account_kind             = var.account_kind
  tags = {
    environment = var.environment
  }
}
#end of storage account definition

resource "azurerm_storage_container" "data" {
  name                  = join("", [var.prefix, var.main_group_name, "storcont"])
  storage_account_name  = azurerm_storage_account.storage_account.name
  container_access_type = var.container_access_type
  #Come back for the life cycle management
  #has_legal_hold = var.change_feed_retention_in_days
}


