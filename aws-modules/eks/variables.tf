########################################
# General Variables
########################################

variable "region" {
  description = "AWS region for the EKS cluster"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-cluster-01"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.31"
}

########################################
# VPC and Networking
########################################

variable "vpc_id" {
  description = "ID of the existing VPC"
  type        = string
}

variable "subnet_id_a" {
  description = "Subnet ID for 1a"
  type        = string
}

variable "subnet_id_b" {
  description = "Subnet ID for 1b"
  type        = string
}

variable "subnet_id_c" {
  description = "Subnet ID for 1c"
  type        = string
}

########################################
# IAM Configuration
########################################

variable "create_cluster_role" {
  description = "Whether to create a new IAM role for the cluster or use an existing one"
  type        = bool
  default     = false
}

variable "service_role_arn" {
  description = "ARN of the IAM role for the EKS cluster service"
  type        = string
  default     = "arn:aws:iam::xxxxxxxxx:role/EKSClusterServiceRole"
}

########################################
# Cluster Configuration
########################################

variable "endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = false
}

variable "endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "enabled_cluster_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

########################################
# Node Group Configuration
########################################

variable "node_group_name" {
  description = "Name of the managed node group"
  type        = string
  default     = "ng-1-workers"
}

variable "node_instance_type" {
  description = "Instance type for worker nodes"
  type        = string
  default     = "t2.micro"
}

variable "node_capacity_type" {
  description = "Capacity type for nodes (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_desired_capacity" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "max_pods_per_node" {
  description = "Maximum number of pods per node (requires custom launch template)"
  type        = number
  default     = null
}

variable "node_labels" {
  description = "Labels to apply to nodes"
  type        = map(string)
  default = {
    role = "workers"
  }
}

########################################
# SSH Configuration
########################################

variable "ssh_key_name" {
  description = "EC2 key pair name for SSH access to nodes"
  type        = string
  default     = "foreksworkloads"
}

variable "ssh_source_security_groups" {
  description = "Security group IDs allowed to SSH to nodes"
  type        = list(string)
  default     = []
}

########################################
# NodePort Security Group
########################################

variable "nodeport_cidr_blocks" {
  description = "CIDR blocks allowed to access NodePort services (30000-32767)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
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
