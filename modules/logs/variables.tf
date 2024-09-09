variable "rg_name" {
  type      = string
  sensitive = true
}
variable "primary_location" {
  type      = string
  sensitive = true
  default = "East US 2"
}
variable "log_name" {
  type      = string
  sensitive = true
}
variable "log_retention_days" {
  type      = number
  sensitive = true
}
variable "log_sku" {
  type      = string
  sensitive = true
}
