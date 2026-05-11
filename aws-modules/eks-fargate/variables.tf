variable "region" {
  description = "AWS region the sandbox is in (e.g., us-east-1)."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "nikeruns-sandbox"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
  default     = "1.33"
}

variable "vpc_id" {
  description = "ID of the VPC provided by the A Cloud Guru sandbox. Discover with: aws ec2 describe-vpcs."
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs (>=2 in different AZs) from the sandbox VPC. These are used for the EKS control plane and (when create_private_subnets=false) for the Fargate profiles. Discover with: aws ec2 describe-subnets."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnet IDs in different AZs are required by EKS."
  }
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the EKS public API endpoint. Tighten to your IP for security; default is 0.0.0.0/0 only because sandbox IPs are ephemeral."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "create_private_subnets" {
  description = "If true, create 2 private subnets + 1 NAT gateway inside the sandbox VPC so Fargate profiles have private subnets to attach to. Set to true when the sandbox provides only public subnets (the common A Cloud Guru case)."
  type        = bool
  default     = false
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the 2 private subnets (only used when create_private_subnets=true). MUST NOT overlap existing subnets in the VPC. Default 172.31.200.0/24 + 172.31.201.0/24 is chosen to avoid collision with the AWS default VPC's 172.31.0.0/20-style subnets."
  type        = list(string)
  default     = ["172.31.200.0/24", "172.31.201.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Exactly 2 private_subnet_cidrs are required (one per AZ)."
  }
}
