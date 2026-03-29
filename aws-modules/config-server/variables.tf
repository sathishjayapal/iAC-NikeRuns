variable "allowed_ssh_cidr" {
  description = "Your public IP in CIDR notation for SSH access (e.g. 1.2.3.4/32). Run: curl -s ifconfig.me"
  type        = string
}

variable "key_name" {
  description = "Name for the EC2 key pair — will be created automatically"
  type        = string
  default     = "config-server-key"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "git_uri" {
  description = "GitHub URI for the Spring Cloud Config git backend"
  type        = string
}

variable "encrypt_key" {
  description = "Encryption key for Spring Cloud Config"
  type        = string
  sensitive   = true
}

variable "username" {
  description = "Spring Security basic auth username"
  type        = string
}

variable "pass" {
  description = "Spring Security basic auth password"
  type        = string
  sensitive   = true
}
