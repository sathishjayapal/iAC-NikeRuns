variable "region" {
  description = "AWS region to deploy the VPC/EKS into"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for resource names and tags"
  type        = string
  default     = "sathish-eks"
}

variable "vpc_cidr" {
  description = "The CIDR range for the VPC"
  type        = string
  default     = "192.168.0.0/16"
}

variable "subnet01_cidr" {
  description = "CIDR block for subnet 01"
  type        = string
  default     = "192.168.64.0/18"
}

variable "subnet02_cidr" {
  description = "CIDR block for subnet 02"
  type        = string
  default     = "192.168.128.0/18"
}

variable "subnet03_cidr" {
  description = "CIDR block for subnet 03 (used only when region has >= 3 AZs)"
  type        = string
  default     = "192.168.192.0/18"
}

########################################
# Private Subnet CIDRs (for Aurora)
# These subnets have no route to the internet.
# Only reachable from inside the VPC.
########################################

variable "private_subnet01_cidr" {
  description = "CIDR for private subnet 1 — Aurora and other internal resources"
  type        = string
  default     = "10.0.11.0/24"
}

variable "private_subnet02_cidr" {
  description = "CIDR for private subnet 2 — Aurora and other internal resources"
  type        = string
  default     = "10.0.12.0/24"
}