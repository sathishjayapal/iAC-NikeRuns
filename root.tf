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
  dns_name_label = var.dns_name_label
  ip_address_type = var.ip_address_type
  configServercpu                 = var.cpu_cores
  configServermemory              = var.memory_in_gb
  configServerport                = var.configServerport
  configServerprotocol            = var.configServerprotocol
  configServerusername            = var.configServerusername
  configServerpass                = var.configServerpass
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

# Configure the Azure provider
provider "azurerm" {
  subscription_id            = var.subscription_id
  tenant_id                  = var.tenant_id
  skip_provider_registration = "true"
  features {}
}


