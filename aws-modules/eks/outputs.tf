########################################
# Cluster Outputs
########################################

output "cluster_id" {
  description = "The name/id of the EKS cluster"
  value       = aws_eks_cluster.this.id
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "The Kubernetes server version for the cluster"
  value       = aws_eks_cluster.this.version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

########################################
# OIDC Provider Outputs
########################################

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC Provider for EKS"
  value       = aws_iam_openid_connect_provider.cluster.url
}

########################################
# Node Group Outputs
########################################

output "node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.workers.id
}

output "node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Node Group"
  value       = aws_eks_node_group.workers.arn
}

output "node_group_status" {
  description = "Status of the EKS node group"
  value       = aws_eks_node_group.workers.status
}

output "node_role_arn" {
  description = "IAM role ARN for the node group"
  value       = aws_iam_role.node_group.arn
}

########################################
# Security Group Outputs
########################################

output "nodeport_security_group_id" {
  description = "Security group ID for NodePort services"
  value       = aws_security_group.nodeport.id
}

output "nodeport_security_group_arn" {
  description = "ARN of the NodePort security group"
  value       = aws_security_group.nodeport.arn
}

########################################
# Launch Template Outputs
########################################

output "launch_template_id" {
  description = "ID of the launch template used by node group"
  value       = aws_launch_template.node_group.id
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.node_group.latest_version
}

########################################
# Kubeconfig Command
########################################

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.this.name}"
}
