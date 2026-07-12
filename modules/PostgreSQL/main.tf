##########################################################################
# Azure PostgreSQL Flexible Server — shared dev database
#
# Provisions ONE server with THREE databases (one per app) + pgvector.
# SKU is Burstable B1ms — cheapest option, suitable for ACG sandbox.
#
# Databases created:
#   event-service        <- eventstracker
#   runsapp_db           <- runs-app
#   runs_ai_analyzer_db  <- runs-ai-analyzer (needs pgvector)
##########################################################################

resource "azurerm_postgresql_flexible_server" "sathishdb-server" {
  name = join("", [var.prefix, var.main_group_name, "postgres"])
  resource_group_name    = var.rg_name
  location               = var.primary_location
  version                = var.postgresql_version
  administrator_login    = var.administrator_login
  administrator_password = var.administrator_login_password

  # Burstable B1ms: 1 vCore, 2 GB RAM. Cheapest tier, fits ACG sandbox.
  # Swap to GP_Standard_D2s_v3 for production-like performance.
  sku_name              = var.sku_name
  storage_mb            = var.storage_mb
  backup_retention_days = var.backup_retention_days

  public_network_access_enabled = true
}

# ── Firewall rule: open to all (dev/ACG sandbox only) ────────────────────────
resource "azurerm_postgresql_flexible_server_firewall_rule" "sathishdbfw" {
  name             = "sathishdb-fw-all"
  server_id        = azurerm_postgresql_flexible_server.sathishdb-server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

# ── Enable pgvector extension ─────────────────────────────────────────────────
# Required for runs-ai-analyzer (Spring AI vector store).
# Must be set BEFORE creating databases; Flyway handles
# "CREATE EXTENSION IF NOT EXISTS vector" inside the DB.
resource "azurerm_postgresql_flexible_server_configuration" "enable_pgvector" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.sathishdb-server.id
  value     = "VECTOR"
}

# ── Databases ─────────────────────────────────────────────────────────────────
resource "azurerm_postgresql_flexible_server_database" "eventstracker_db" {
  name      = "event-service"
  server_id = azurerm_postgresql_flexible_server.sathishdb-server.id
  charset   = "UTF8"
  collation = "en_US.utf8"

  depends_on = [azurerm_postgresql_flexible_server_configuration.enable_pgvector]
}

resource "azurerm_postgresql_flexible_server_database" "runsapp_db" {
  name      = "runsapp_db"
  server_id = azurerm_postgresql_flexible_server.sathishdb-server.id
  charset   = "UTF8"
  collation = "en_US.utf8"

  depends_on = [azurerm_postgresql_flexible_server_configuration.enable_pgvector]
}

resource "azurerm_postgresql_flexible_server_database" "runsai_db" {
  name      = "runs_ai_analyzer_db"
  server_id = azurerm_postgresql_flexible_server.sathishdb-server.id
  charset   = "UTF8"
  collation = "en_US.utf8"

  depends_on = [azurerm_postgresql_flexible_server_configuration.enable_pgvector]
}

resource "azurerm_postgresql_flexible_server_database" "githubcleaner_db" {
  name      = "my-github-cleaner"
  server_id = azurerm_postgresql_flexible_server.sathishdb-server.id
  charset   = "UTF8"
  collation = "en_US.utf8"

  depends_on = [azurerm_postgresql_flexible_server_configuration.enable_pgvector]
}

resource "azurerm_postgresql_flexible_server_database" "dbcleaner_db" {
  name      = "dbcleaner"
  server_id = azurerm_postgresql_flexible_server.sathishdb-server.id
  charset   = "UTF8"
  collation = "en_US.utf8"

  depends_on = [azurerm_postgresql_flexible_server_configuration.enable_pgvector]
}
