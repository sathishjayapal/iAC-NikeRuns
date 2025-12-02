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
  description = "Security group ID attached to the EKS cluster (auto-created by EKS)"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "control_plane_security_group_id" {
  description = "Security group ID for control plane (matching eksctl ControlPlaneSecurityGroup)"
  value       = aws_security_group.control_plane.id
}

output "nodeport_security_group_id" {
  description = "Security group ID for NodePort services"
  value       = aws_security_group.nodeport.id
}

output "all_security_groups" {
  description = "All security groups associated with the cluster"
  value = {
    cluster_sg       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
    control_plane_sg = aws_security_group.control_plane.id
    nodeport_sg      = aws_security_group.nodeport.id
  }
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
  value       = var.enable_oidc ? aws_iam_openid_connect_provider.cluster[0].arn : null
}

output "oidc_provider_url" {
  description = "URL of the OIDC Provider for EKS"
  value       = var.enable_oidc ? aws_iam_openid_connect_provider.cluster[0].url : null
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

output "launch_template_id" {
  description = "ID of the launch template used by node group"
  value       = aws_launch_template.node_group.id
}

output "launch_template_latest_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.node_group.latest_version
}

########################################
# EKS Addons Outputs
########################################

output "addons_installed" {
  description = "List of EKS addons installed (matching eksctl successful addons)"
  value = [
    aws_eks_addon.vpc_cni.addon_name,
    aws_eks_addon.kube_proxy.addon_name
  ]
}

output "coredns_note" {
  description = "Note about CoreDNS"
  value       = "CoreDNS runs automatically but is not managed as an EKS addon to avoid AWS stuck CREATING bug"
}

########################################
# Kubeconfig Command
########################################

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.this.name}"
}

########################################
# AWS Load Balancer Controller Outputs
########################################

output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the IAM role for AWS Load Balancer Controller"
  value       = var.enable_aws_load_balancer_controller ? aws_iam_role.aws_load_balancer_controller[0].arn : null
}

output "aws_load_balancer_controller_policy_arn" {
  description = "ARN of the IAM policy for AWS Load Balancer Controller"
  value       = var.enable_aws_load_balancer_controller ? aws_iam_policy.aws_load_balancer_controller[0].arn : null
}

output "aws_load_balancer_controller_status" {
  description = "Status of AWS Load Balancer Controller deployment"
  value       = var.enable_aws_load_balancer_controller ? "Enabled" : "Disabled"
}
