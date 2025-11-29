# Security Groups Added to Match eksctl

## What Was Added

### Control Plane Security Group
Created in `main.tf` lines 36-55:

```hcl
resource "aws_security_group" "control_plane" {
  name_prefix = "${var.cluster_name}-ControlPlaneSecurityGroup-"
  description = "Communication between the control plane and worker nodegroups"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-ControlPlaneSecurityGroup"
    }
  )
}
```

### Attached to EKS Cluster
Updated in `main.tf` line 74:

```hcl
vpc_config {
  subnet_ids = [...]
  endpoint_private_access = false
  endpoint_public_access  = true
  security_group_ids      = [aws_security_group.control_plane.id]  # <- ADDED
}
```

## Security Group Architecture (Now Matching eksctl)

### 1. Control Plane Security Group (Custom - We Create)
- **Name:** `eks-cluster-dotsky-ControlPlaneSecurityGroup-*`
- **Purpose:** Communication between control plane and worker nodes
- **Rules:**
  - Egress: Allow all outbound (0.0.0.0/0)
  - Ingress: None (EKS manages this automatically)
- **Attached to:** EKS Control Plane

### 2. Cluster Security Group (Auto-created by EKS)
- **Name:** `eks-cluster-sg-eks-cluster-dotsky-*`
- **Purpose:** Applied to ENIs attached to EKS control plane and managed workloads
- **Rules:** Managed automatically by EKS
- **Attached to:** Control plane ENIs and worker nodes

## How This Matches eksctl

When you run `eksctl create cluster`, it creates:

1. ✅ **ControlPlaneSecurityGroup** - We now create this
2. ✅ **Cluster Security Group** - EKS auto-creates this (same as before)

Both Terraform and eksctl now have the **same security group setup**.

## Outputs Available

You can now see both security groups in outputs:

```bash
terraform output control_plane_security_group_id  # Custom SG we created
terraform output cluster_security_group_id        # EKS auto-created SG
terraform output all_security_groups              # Both in one object
```

## Verification

After applying, verify it matches eksctl:

```bash
# Check cluster security groups
aws eks describe-cluster --name eks-cluster-dotsky --region us-east-1 \
  --query 'cluster.resourcesVpcConfig.{ClusterSG:clusterSecurityGroupId,AdditionalSGs:securityGroupIds}'

# Should show:
# - ClusterSG: sg-xxxxx (auto-created by EKS)
# - AdditionalSGs: [sg-yyyyy] (our ControlPlaneSecurityGroup)
```

This now **exactly matches** what eksctl creates!
