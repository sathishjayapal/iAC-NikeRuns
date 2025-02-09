#Root Main properties
variable "rg_name" {
  type      = string
}
variable "prefix" {
  type        = string
  description = "prefix to be used for resource."
  nullable    = false
}
variable "main_group_name" {
  type      = string
  sensitive = true
  default   = "sathish-main-group"
}
variable "environment" {
  type        = string
  description = "environment to be used for resource."
  nullable    = false
}

variable "primary_location" {
  type      = string
  sensitive = true
  default = "South Central US"
}
variable "ip_address_type" {
  type        = string
  description = "Public/Private endpoint."
}
variable "configServerImageName" {
  type        = string
  description = "The name of the image to use for the container."
  nullable    = false

}
variable "configServercpu" {
  type        = number
  description = "The number of CPU cores to allocate to the container."
  nullable    = false
}
variable "configServermemory" {
  type        = number
  description = "The amount of memory to allocate to the container."
  nullable    = false
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
variable "appserviceport" {
  type        = string
  description = "The port to use for the container."
  nullable    = false
}
variable "git_uri" {
  type        = string
  description = "The git url to use for the container."
  nullable    = false
}
variable "encrypt_key" {
  type        = string
  description = "The encrypt key to use for the container."
  nullable    = false
}
variable "jar_file" {
  type        = string
  description = "The jar file name use for the container."
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
variable "os_type" {
  type        = string
  description = "OS type."
}
variable "dns_name_label" {
  type        = string
  description = "FQDN Name"
}
