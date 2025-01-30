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
variable "prefix" {
  type        = string
  description = "prefix to be used for resource."
  nullable    = false
}
