output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA. Used by kubeconfig."
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for IRSA."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL of the EKS cluster."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "fargate_pod_execution_role_arn" {
  description = "ARN of the Fargate pod execution role."
  value       = aws_iam_role.fargate_pod_execution.arn
}

output "kubeconfig_command" {
  description = "Run this to update your local kubeconfig."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.this.name}"
}
