########################################
# General Variables
########################################

variable "region" {
  description = "AWS region for the EKS cluster"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.34"
}

########################################
# VPC and Networking
########################################

variable "vpc_id" {
  description = "ID of the existing VPC"
  type        = string
}

variable "subnet_id_a" {
  description = "Subnet ID for availability zone a"
  type        = string
}

variable "subnet_id_b" {
  description = "Subnet ID for availability zone b"
  type        = string
}

variable "subnet_id_c" {
  description = "Subnet ID for availability zone c"
  type        = string
}

########################################
# IAM Configuration
########################################

variable "service_role_arn" {
  description = "ARN of the IAM role for the EKS cluster service"
  type        = string
}

variable "enable_oidc" {
  description = "Enable OIDC provider for IRSA"
  type        = bool
  default     = true
}

########################################
# Node Group Configuration
########################################

variable "node_group_name" {
  description = "Name of the managed node group"
  type        = string
}

variable "node_instance_type" {
  description = "Instance type for worker nodes"
  type        = string
}

variable "node_desired_capacity" {
  description = "Desired number of worker nodes"
  type        = number
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
}

variable "max_pods_per_node" {
  description = "Maximum number of pods per node"
  type        = number
  default     = null
}

variable "node_labels" {
  description = "Labels to apply to nodes"
  type        = map(string)
  default     = {}
}

########################################
# SSH Configuration
########################################

variable "ssh_key_name" {
  description = "EC2 key pair name for SSH access to nodes"
  type        = string
}

########################################
# Tags
########################################

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "node_group_tags" {
  description = "Additional tags for node group"
  type        = map(string)
  default     = {}
}

########################################
# AWS Load Balancer Controller
########################################

variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "aws_load_balancer_controller_version" {
  description = "Version of AWS Load Balancer Controller Helm chart"
  type        = string
  default     = "1.6.2"
}
