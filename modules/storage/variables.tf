variable "rg-name" {
  type        = string
  description = "Resrouce group name."
  nullable    = false

}
variable "main_group_name" {
  type      = string
  sensitive = true
}
variable "primary_location" {
  type      = string
  sensitive = true
  default = "South Central US"
}

#end of input variables
# Define the storage account attributes

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
variable "prefix" {
  type        = string
  description = "prefix to be used for resource."
  nullable    = false
}
variable "container_access_type" {
  type        = string
  description = "The access type for the storage container."
  nullable    = false
}

# Define the input variables
variable "environment" {
  default = "dev"
}
