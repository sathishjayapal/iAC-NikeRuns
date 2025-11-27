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