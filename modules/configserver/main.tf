
resource "azurerm_container_group" "container_config_group" {
  name                = join("", [var.prefix, var.main_group_name, "configsrvrcontgrp"])
  location            = var.primary_location
  resource_group_name = var.rg_name
  ip_address_type     = var.ip_address_type
  dns_name_label      = "${var.main_group_name}-configcont"
  os_type             = var.os_type

  container {
    name   = join("", [var.prefix, var.main_group_name, "contnr"])
    image  = var.configServerImageName
    cpu    = var.configServercpu
    memory = var.configServermemory
    ports {
      port     = var.configServerport
      protocol = var.configServerprotocol
    }
    environment_variables = {
      "username" = var.configServerusername
      "pass"     = var.configServerpass
    }

  }
  image_registry_credential {
    server   = var.docker_registry_server_url
    username = var.docker_registry_server_username
    password = var.docker_registry_server_password
  }

  tags = {
    environment = var.environment
  }
}


