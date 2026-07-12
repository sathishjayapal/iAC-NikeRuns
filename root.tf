terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
    }
  }
}
module "storagemodule" {
  source = "./modules/storage"
  account_tier = var.account_tier
  account_replication_type = var.account_replication_type
  account_kind = var.account_kind
  prefix = var.prefix
  rg-name = var.rg_name
  environment = var.primary_location
  container_access_type = var.container_access_type
  main_group_name = var.main_group_name
}

module "configservermodule" {
  source = "./modules/configserver"
  dns_name_label                  = var.dns_name_label
  ip_address_type                 = var.ip_address_type
  configServercpu                 = var.cpu_cores
  configServermemory              = var.memory_in_gb
  configServerport                = var.configServerport
  configServerprotocol            = var.configServerprotocol
  configServerusername            = var.configServerusername
  configServerpass                = var.configServerpass
  appserviceport                  = var.appserviceport
  git_uri                         = var.git_uri
  encrypt_key                     = var.encrypt_key
  jar_file                        = var.jar_file
  docker_registry_server_password = var.docker_registry_server_password
  docker_registry_server_url      = var.docker_registry_server_url
  docker_registry_server_username = var.docker_registry_server_username
  rg_name                         = var.rg_name
  prefix                          = var.prefix
  main_group_name                 = var.main_group_name
  os_type                         = var.appservice-ostype
  primary_location = var.primary_location
  configServerImageName = var.configServerImageName
  environment = var.environment
}

module "loganalyticsmodule" {
  source = "./modules/logs"
  primary_location = var.primary_location
  rg_name = var.rg_name
  log_name           = var.log_name
  log_retention_days = var.log_retention_days
  log_sku            = var.log_sku
}
module "flexipostgresmodule" {
  source  = "./modules/PostgreSQL"
  primary_location             = var.primary_location
  rg_name                      = var.rg_name
  prefix                       = var.prefix
  main_group_name              = var.main_group_name
  administrator_login_password = var.pg_admin_password
}

# ── PostgreSQL root-level outputs (consumed by acg-start.sh) ─────────────────
output "pg_host" {
  value       = module.flexipostgresmodule.db_host
  description = "PostgreSQL FQDN"
}

output "pg_port" {
  value       = module.flexipostgresmodule.db_port
  description = "PostgreSQL port"
}

output "pg_admin_user" {
  value       = module.flexipostgresmodule.db_admin_user
  description = "PostgreSQL admin login"
}

output "pg_admin_password" {
  value       = module.flexipostgresmodule.db_admin_password
  sensitive   = true
  description = "PostgreSQL admin password"
}

output "jdbc_eventstracker" {
  value     = module.flexipostgresmodule.jdbc_eventstracker
  sensitive = true
}

output "jdbc_runsapp" {
  value     = module.flexipostgresmodule.jdbc_runsapp
  sensitive = true
}

output "jdbc_runsai" {
  value     = module.flexipostgresmodule.jdbc_runsai
  sensitive = true
}

output "db_name_eventstracker" {
  value = module.flexipostgresmodule.db_name_eventstracker
}

output "db_name_runsapp" {
  value = module.flexipostgresmodule.db_name_runsapp
}

output "db_name_runsai" {
  value = module.flexipostgresmodule.db_name_runsai
}

output "jdbc_githubcleaner" {
  value     = module.flexipostgresmodule.jdbc_githubcleaner
  sensitive = true
}

output "jdbc_dbcleaner" {
  value     = module.flexipostgresmodule.jdbc_dbcleaner
  sensitive = true
}

output "db_name_githubcleaner" {
  value = module.flexipostgresmodule.db_name_githubcleaner
}

output "db_name_dbcleaner" {
  value = module.flexipostgresmodule.db_name_dbcleaner
}
module "eventgridmodule" {
  source = "./modules/eventgrid"
  rg-name = var.rg_name
  primary_location = var.primary_location
  prefix = var.prefix
  main_group_name = var.main_group_name
}

module "servicebusmodule" {
  source = "./modules/service-bus"
  rg-name = var.rg_name
  primary_location = var.primary_location
  prefix = var.prefix
  main_group_name = var.main_group_name
}


# Configure the Azure provider
provider "azurerm" {
  subscription_id            = var.subscription_id
  tenant_id                  = var.tenant_id
  skip_provider_registration = "true"
  features {}
}


