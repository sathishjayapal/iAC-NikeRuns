#Main properties
variable "tenant_id" {
  type      = string
  sensitive = true
}
variable "base_name" {
  type      = string
  sensitive = true
}
variable "subscription_id" {
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
variable "primary_location" {
  type      = string
  sensitive = true
}
#End of Main properties

#Start of resource group names
variable "rg_name" {
  type      = string
  sensitive = true
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

#Container related properties
variable "image" {
  type        = string
  description = "Container image to deploy. Should be of the form repoName/imagename:tag for images stored in public Docker Hub, or a fully qualified URI for other registries. Images from private registries require additional registry credentials."
}
variable "ip_address_type" {
  type        = string
  description = "Public/Private endpoint."
}
variable "os_type" {
  type        = string
  description = "OS type."
}
variable "dns_name_label" {
  type        = string
  description = "FQDN Name"
}
variable "port" {
  type        = number
  description = "Port to open on the container and the public IP address."
}

variable "cpu_cores" {
  type        = number
  description = "The number of CPU cores to allocate to the container."
}

variable "memory_in_gb" {
  type        = number
  description = "The amount of memory to allocate to the container in gigabytes."
}

variable "restart_policy" {
  type        = string
  description = "The behavior of Azure runtime if container has stopped."
  validation {
    condition     = contains(["Always", "Never", "OnFailure"], var.restart_policy)
    error_message = "The restart_policy must be one of the following: Always, Never, OnFailure."
  }
}
#End Container related properties
