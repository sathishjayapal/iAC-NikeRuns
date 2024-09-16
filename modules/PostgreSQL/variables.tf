# This variable defines a prefix to be used for resources.
variable "prefix" {
type = string
description = "prefix is the prefix to be used for resource."
}

# This variable defines the main group name.
variable "main_group_name" {
type        = string
description = "main_group_name is the main group name."
}

# This variable defines the resource group name.
variable "rg_name" {
type        = string
description = "rg_name is the resource group name."
}

# This variable defines the primary location for resources.
variable "primary_location" {
type        = string
description = "primary_location is the primary location."
default     = "South Central US"
}

# This variable defines the SKU name for the resource.
variable "sku_name" {
type    = string
  description = "sku_name is the SKU name for the resource."
default = "GP_Standard_D4s_v3"
}

# This variable defines the storage size in megabytes.
variable "storage_mb" {
type    = number
default = "32768"
description = "storage_mb is the storage size in megabytes."
}

# This variable defines the number of days to retain backups.
variable "backup_retention_days" {
type    = number
default = 7
description = "backup_retention_days is the number of days to retain backups."
}

# This variable defines the administrator login name.
variable "administrator_login" {
type    = string
default = "psqladmin"
description = "administrator_login is the administrator login name."
}

# This variable defines the administrator login password.
# It is marked as sensitive to avoid exposing it in logs.
variable "administrator_login_password" {
type      = string
sensitive = true
default   = "psqladminpas$"
description = "administrator_login_password is the administrator login password."
}

# This variable defines the PostgreSQL version.
# It is marked as sensitive to avoid exposing it in logs.
variable "postgresql_version" {
type      = string
sensitive = true
default   = "12"
description = "postgresql_version is the PostgreSQL version."
}
