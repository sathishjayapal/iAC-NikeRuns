resource azurerm_postgresql_flexible_server "sathishdb-server" {
    name                = join("", [var.prefix, var.main_group_name, "postgres"])
    resource_group_name = var.rg_name
    location            = "EASTUS"
    sku_name            = var.sku_name
    storage_mb          = var.storage_mb
    administrator_password = "pas$word1234"
    backup_retention_days = var.backup_retention_days
    administrator_login = var.administrator_login
    version = var.postgresql_version
  }
resource "azurerm_postgresql_flexible_server_firewall_rule" "sathishdbfw" {
    name             = "sathishdb-fw"
    server_id        = azurerm_postgresql_flexible_server.sathishdb-server.id
    start_ip_address = "0.0.0.0"
    end_ip_address   = "255.255.255.255"
}

