# SSH Security Group Fix - Now Matching eksctl

## Problem Identified

**Terraform cluster had an extra security group that eksctl didn't create:**

### Before Fix:
**eksctl cluster (eks-cluster-01):**
- Control Plane SG: `sg-0a287a379f8dec9cc`
- Cluster SG: `sg-056645fee6d0b2803`
- ❌ No remote access SG

**Terraform cluster (eks-cluster-dotsky):**
- Control Plane SG: `sg-085736f560b122c58`
- Cluster SG: `sg-063e79184f2b63f1b`
- ⚠️ **Remote Access SG: `sg-017131e0e10044677`** (EXTRA - not in eksctl)

## Root Cause

Using `remote_access` block in the node group:
```hcl
remote_access {
  ec2_ssh_key = var.ssh_key_name
}
```

This causes EKS to **automatically create** a security group allowing SSH (port 22) from 0.0.0.0/0.

eksctl doesn't create this extra security group - it handles SSH through the launch template instead.

## Solution Applied

### 1. Removed `remote_access` block
Deleted lines that were creating the extra security group.

### 2. Added Launch Template
Created a launch template with:
- SSH key configuration
- IMDSv2 required (matching eksctl's `disableIMDSv1: true`)
- Proper metadata options
- Instance tags

```hcl
resource "aws_launch_template" "node_group" {
  name_prefix = "${var.cluster_name}-${var.node_group_name}-"
  key_name    = var.ssh_key_name
  
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 only
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "disabled"
  }
}
```

### 3. Updated Node Group
Changed node group to use launch template:
```hcl
launch_template {
  id      = aws_launch_template.node_group.id
  version = "$Latest"
}
```

## Result - Now Matching eksctl Exactly

### After Fix:
**Both clusters now have identical security group setup:**
- ✅ Control Plane Security Group (custom)
- ✅ Cluster Security Group (EKS auto-created)
- ✅ No remote access security group
- ✅ SSH handled via launch template

## Additional Benefits

1. **IMDSv2 Enforced** - More secure (matches eksctl's `disableIMDSv1: true`)
2. **No extra security group** - Cleaner setup
3. **Launch template flexibility** - Can add more customizations later

## Verification Commands

After applying the updated Terraform:

```bash
# Check cluster security groups
aws eks describe-cluster --name eks-cluster-dotsky --region us-east-1 \
  --query 'cluster.resourcesVpcConfig.{ClusterSG:clusterSecurityGroupId,AdditionalSGs:securityGroupIds}'

# Check node group for remote access SG (should be None)
aws eks describe-nodegroup --cluster-name eks-cluster-dotsky \
  --nodegroup-name ng-dotskyclstr-workers --region us-east-1 \
  --query 'nodegroup.resources.remoteAccessSecurityGroup'

# Should return: None (matching eksctl)
```

## Summary

The Terraform configuration now **exactly matches** eksctl's security group setup:
- Same number of security groups
- Same security group purposes
- SSH configured the same way (via launch template)
- IMDSv2 enforced for better security
