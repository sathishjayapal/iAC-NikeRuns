locals {
  # Always include subnet01 and subnet02
  all_subnet_ids = concat(
    [
      aws_subnet.subnet01.id,
      aws_subnet.subnet02.id,
    ],
    # Conditionally add subnet03 (0 or 1 element depending on count)
    aws_subnet.subnet03[*].id
  )
}

output "vpc_id" {
  description = "The VPC Id"
  value       = aws_vpc.this.id
}

output "subnet_ids" {
  description = "All public subnets in the VPC (2 or 3 depending on AZ count)"
  value       = local.all_subnet_ids
}

output "security_groups" {
  description = "Security group for the cluster control plane communication with worker nodes"
  value       = [aws_security_group.control_plane.id]
}