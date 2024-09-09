#Main properties
variable "tenant_id" {
  type      = string
  sensitive = true
}
variable "base_name" {
  type      = string
  sensitive = true
  default   = "sathish"
}
variable "main_group_name" {
  type      = string
  sensitive = true
  default   = "sathish-main-group"
}
variable "subscription_id" {
  type      = string
  sensitive = true
}

variable "primary_location" {
  type      = string
  sensitive = true
  default = "South Central US"
}
variable "secondary_location" {
  type      = string
  sensitive = true
  default = "Central US"
}
variable "prefix" {
  type        = string
  description = "prefix to be used for resource."
  nullable    = false
}
variable "environment" {
  type        = string
  description = "environment to be used for resource."
  nullable    = false
}


#End of Main properties

#Start of resource group names
variable "rg_name" {
  type      = string
  sensitive = true
}

variable "timeout_min" {
  description = "Time out minimum parameter variable"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.timeout_min) > 0
    error_message = "Timeout min cannot be more than 2 digit length"
  }
}
variable "timeout_delete" {
  type      = string
  sensitive = true
  validation {
    condition     = length(var.timeout_delete) > 0
    error_message = "Timeout delete cannot be more than 2 digit length"
  }
}
#End of resource group names

#Log related properties
variable "log_name" {
  type      = string
  sensitive = true
}
variable "log_sku" {
  type      = string
  sensitive = true
}
variable "log_retention_days" {
  type      = number
  sensitive = true
}

#End Log related properties

#Container Apps related properties

variable "ip_address_type" {
  type        = string
  description = "Public/Private endpoint."
}

variable "dns_name_label" {
  type        = string
  description = "FQDN Name"
}
variable "cpu_cores" {
  type        = number
  description = "The number of CPU cores to allocate to the container."
  default = 1
}

variable "memory_in_gb" {
  type        = number
  description = "The amount of memory to allocate to the container in gigabytes."
  default = 2
}

variable "configServerport" {
  type        = number
  description = "The port on which the container listens."
  nullable    = false
}
variable "configServerprotocol" {
  type        = string
  description = "The protocol that the container uses."
  nullable    = false
}
variable "configServerusername" {
  type        = string
  description = "The username to use for the container."
  nullable    = false
}
variable "configServerpass" {
  type        = string
  description = "The password to use for the container."
  nullable    = false
}
variable "docker_registry_server_url" {
  type        = string
  description = "The URL of the Docker registry server."
  nullable    = false
}
variable "docker_registry_server_username" {
  type        = string
  description = "The username to use for the Docker registry server."
  nullable    = false
}
variable "docker_registry_server_password" {
  type        = string
  description = "The password to use for the Docker registry server."
  nullable    = false
}

#End Container related properties

#AppService properties
variable "configServerImageName" {
  type        = string
  description = "Full URL for the docker image used in app service"
}
variable "appservice-ostype" {
  type        = string
  description = "Type of ostype to be used in app service"
}

#storage account attributes
variable "account_tier" {
  type        = string
  description = "The storage account tier."
  nullable    = false
}
variable "account_replication_type" {
  type        = string
  description = "The storage account replication type."
  nullable    = false
}
variable "account_kind" {
  type        = string
  description = "The storage account kind."
  nullable    = false

}

variable "container_access_type" {
  type        = string
  description = "The access type for the storage container."
  nullable    = false
}

