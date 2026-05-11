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
  default     = "1.30"
}

variable "vpc_id" {
  description = "ID of the VPC provided by the A Cloud Guru sandbox. Discover with: aws ec2 describe-vpcs."
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs (>=2 in different AZs) from the sandbox VPC. Discover with: aws ec2 describe-subnets."
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
