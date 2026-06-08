variable "prefix" {
  type        = string
  description = "Prefix used in resource names."
}

variable "main_group_name" {
  type        = string
  description = "Main group name used in resource names."
}

variable "rg_name" {
  type        = string
  description = "Azure resource group name."
}

variable "primary_location" {
  type        = string
  description = "Azure region."
  default     = "East US"
}

# ── Server sizing ─────────────────────────────────────────────────────────────
# Default is Burstable B1ms: cheapest SKU, fine for ACG sandbox.
# For better performance use: GP_Standard_D2s_v3
variable "sku_name" {
  type        = string
  description = "PostgreSQL Flexible Server SKU name."
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  type        = number
  description = "Storage size in megabytes."
  default     = 32768
}

variable "backup_retention_days" {
  type        = number
  description = "Number of days to retain backups."
  default     = 7
}

# ── Auth ──────────────────────────────────────────────────────────────────────
variable "administrator_login" {
  type        = string
  description = "PostgreSQL administrator login name."
  default     = "psqladmin"
}

variable "administrator_login_password" {
  type        = string
  sensitive   = true
  description = "PostgreSQL administrator password. Pass via tfvars or TF_VAR_administrator_login_password — never hardcode."
}

# ── Version ───────────────────────────────────────────────────────────────────
# Must be >= 13 for pgvector support on Azure Flexible Server.
variable "postgresql_version" {
  type        = string
  description = "PostgreSQL major version. Minimum 13 for pgvector."
  default     = "16"
}
