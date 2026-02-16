# VPC Deletion Issues - Complete Fix Guide

## Problems

You're seeing these aws-nuke errors:

```
us-east-1 - EC2VPC - vpc-0f67b69c39640293b - [tag:Name: "sathish-eks-VPC"] - failed
us-east-1 - EC2DHCPOption - dopt-ea048c90 - [DefaultVPC: "true"] - failed
us-east-1 - CloudWatchAnomalyDetector - Invocations - [MetricName: "Invocations"] - waiting
```

## Root Causes

1. **VPC has active dependencies**:
   - RDS cluster `runs-app-prod-aurora-pg` with instances
   - DB subnet groups
   - Security groups
   - Subnets, route tables, internet gateways
   - CloudWatch anomaly detectors

2. **Terraform still references the VPC**:
   - Hardcoded VPC ID in `examples/prod/main.tf`
   - Terraform state may still track resources

## Solution Overview

You need to:
1. ✅ Delete all RDS resources
2. ✅ Clean up VPC dependencies  
3. ✅ Remove Terraform state references
4. ✅ Delete CloudWatch resources
5. ✅ Finally delete the VPC

---

## Quick Fix (Recommended)

### Step 1: Delete RDS Resources First

```bash
cd /Users/sathishjayapal/IdeaProjects/iAC-NikeRuns/aws-modules/runs-app-db

# Fix RDS deletion protection and delete
./fix-rds-deletion.sh
```

**Wait 10-15 minutes for RDS deletion to complete.**

### Step 2: Clean Up VPC Dependencies

```bash
# Clean up all VPC-related resources
./fix-vpc-deletion.sh vpc-0f67b69c39640293b
```

### Step 3: Re-run aws-nuke

The VPC should now be deletable by aws-nuke.

---

## Detailed Manual Cleanup

If the automated scripts don't work, follow these steps:

### 1. Delete RDS Cluster and Instances

```bash
REGION="us-east-1"
CLUSTER_ID="runs-app-prod-aurora-pg"
INSTANCE_ID="runs-app-prod-writer-1"

# Disable deletion protection
aws rds modify-db-cluster \
    --db-cluster-identifier "$CLUSTER_ID" \
    --no-deletion-protection \
    --apply-immediately \
    --region "$REGION"

# Delete instance
aws rds delete-db-instance \
    --db-instance-identifier "$INSTANCE_ID" \
    --skip-final-snapshot \
    --region "$REGION"

# Wait for instance deletion
aws rds wait db-instance-deleted \
    --db-instance-identifier "$INSTANCE_ID" \
    --region "$REGION"

# Delete cluster
aws rds delete-db-cluster \
    --db-cluster-identifier "$CLUSTER_ID" \
    --skip-final-snapshot \
    --region "$REGION"

# Wait for cluster deletion
aws rds wait db-cluster-deleted \
    --db-cluster-identifier "$CLUSTER_ID" \
    --region "$REGION"
```

### 2. Delete DB Subnet Groups

```bash
VPC_ID="vpc-0f67b69c39640293b"

# List DB subnet groups
aws rds describe-db-subnet-groups \
    --region us-east-1 \
    --query "DBSubnetGroups[?VpcId=='$VPC_ID'].DBSubnetGroupName" \
    --output text

# Delete each one
aws rds delete-db-subnet-group \
    --db-subnet-group-name runs-app-prod-db-subnets \
    --region us-east-1
```

### 3. Delete Security Groups

```bash
# List security groups in VPC
aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --region us-east-1 \
    --query "SecurityGroups[?GroupName!='default'].[GroupId,GroupName]" \
    --output table

# For each security group, first remove all rules, then delete
SG_ID="sg-xxxxx"  # Replace with actual ID

# Remove ingress rules
aws ec2 describe-security-groups \
    --group-ids "$SG_ID" \
    --region us-east-1 \
    --query "SecurityGroups[0].IpPermissions" > /tmp/ingress.json

aws ec2 revoke-security-group-ingress \
    --group-id "$SG_ID" \
    --ip-permissions file:///tmp/ingress.json \
    --region us-east-1

# Remove egress rules
aws ec2 describe-security-groups \
    --group-ids "$SG_ID" \
    --region us-east-1 \
    --query "SecurityGroups[0].IpPermissionsEgress" > /tmp/egress.json

aws ec2 revoke-security-group-egress \
    --group-id "$SG_ID" \
    --ip-permissions file:///tmp/egress.json \
    --region us-east-1

# Delete security group
aws ec2 delete-security-group \
    --group-id "$SG_ID" \
    --region us-east-1
```

### 4. Delete Network Resources

```bash
# Delete subnets
aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --region us-east-1 \
    --query "Subnets[*].SubnetId" \
    --output text | xargs -n1 aws ec2 delete-subnet \
    --region us-east-1 \
    --subnet-id

# Detach and delete internet gateway
IGW_ID=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --region us-east-1 \
    --query "InternetGateways[0].InternetGatewayId" \
    --output text)

aws ec2 detach-internet-gateway \
    --internet-gateway-id "$IGW_ID" \
    --vpc-id "$VPC_ID" \
    --region us-east-1

aws ec2 delete-internet-gateway \
    --internet-gateway-id "$IGW_ID" \
    --region us-east-1

# Delete route tables (non-main)
aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --region us-east-1 \
    --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" \
    --output text | xargs -n1 aws ec2 delete-route-table \
    --region us-east-1 \
    --route-table-id
```

### 5. Delete CloudWatch Anomaly Detectors

```bash
# List anomaly detectors
aws cloudwatch describe-anomaly-detectors \
    --region us-east-1 \
    --max-results 100

# Delete specific detector (replace with actual metric details)
aws cloudwatch delete-anomaly-detector \
    --namespace AWS/Lambda \
    --metric-name Invocations \
    --stat Average \
    --region us-east-1
```

### 6. Delete VPC

```bash
aws ec2 delete-vpc \
    --vpc-id "$VPC_ID" \
    --region us-east-1
```

---

## Terraform State Cleanup

If you've been managing this VPC with Terraform, clean up the state:

```bash
cd /Users/sathishjayapal/IdeaProjects/iAC-NikeRuns/aws-modules/runs-app-db/examples/prod

# Remove resources from Terraform state
terraform state list
terraform state rm module.runs_app_db
terraform state rm data.aws_vpc.existing
terraform state rm data.aws_subnets.database

# Or just delete the state file if no longer needed
rm terraform.tfstate terraform.tfstate.backup
```

---

## Update Terraform Example

The example code has a hardcoded VPC ID. Update it to be dynamic:

```hcl
# Instead of:
data "aws_vpc" "existing" {
  id = "vpc-0f67b69c39640293b"  # Hardcoded - BAD
}

# Use:
data "aws_vpc" "existing" {
  tags = {
    Name = "sathish-eks-VPC"
  }
}

# Or even better, use variables:
variable "vpc_id" {
  description = "VPC ID for the database"
  type        = string
}

# Then reference:
vpc_id = var.vpc_id
```

---

## Troubleshooting

### Error: "Cannot delete VPC - Network interfaces still exist"

```bash
# Find network interfaces in VPC
aws ec2 describe-network-interfaces \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --region us-east-1 \
    --query "NetworkInterfaces[*].[NetworkInterfaceId,Description,Status]" \
    --output table

# Delete them
aws ec2 delete-network-interface \
    --network-interface-id eni-xxxxx \
    --region us-east-1
```

### Error: "Cannot delete subnet - Dependencies exist"

This usually means ENIs (Elastic Network Interfaces) are still attached. Wait a few minutes after deleting RDS or EC2 instances.

### Error: "Security group in use"

Security groups may reference each other. Remove all ingress/egress rules first, then delete in reverse dependency order.

### CloudWatch Anomaly Detector Won't Delete

You may need to specify all the exact dimensions:

```bash
# Get full details
aws cloudwatch describe-anomaly-detectors \
    --region us-east-1 \
    --output json > anomaly-detectors.json

# Then use exact parameters from the output for deletion
```

---

## Prevention for Future

### 1. Use Dynamic VPC References

```hcl
# Query VPC by tag instead of hardcoding ID
data "aws_vpc" "main" {
  tags = {
    Environment = "production"
    Project     = "runs-app"
  }
}
```

### 2. Use Terraform Workspaces

```bash
terraform workspace new prod
terraform workspace new dev
```

### 3. Always Use Terraform Destroy

Instead of using aws-nuke, use:

```bash
terraform destroy
```

This removes resources in the correct order.

### 4. Tag Everything

```hcl
tags = {
  Environment = "prod"
  ManagedBy   = "terraform"
  Project     = "runs-app"
  Owner       = "your-team"
}
```

Then use aws-nuke filters to skip or include based on tags.

---

## Verification

After cleanup, verify everything is deleted:

```bash
# Check VPC
aws ec2 describe-vpcs \
    --vpc-ids vpc-0f67b69c39640293b \
    --region us-east-1
# Should return: InvalidVpcID.NotFound

# Check RDS
aws rds describe-db-clusters \
    --db-cluster-identifier runs-app-prod-aurora-pg \
    --region us-east-1
# Should return: DBClusterNotFoundFault

# Check subnets
aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=vpc-0f67b69c39640293b" \
    --region us-east-1
# Should return empty list
```

---

## Summary of Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `fix-rds-deletion.sh` | Delete RDS cluster/instances | `./fix-rds-deletion.sh` |
| `fix-vpc-deletion.sh` | Clean up VPC dependencies | `./fix-vpc-deletion.sh vpc-0f67b69c39640293b` |

## Related Documentation

- [RDS_DELETION_FIX.md](./RDS_DELETION_FIX.md) - RDS-specific deletion guide
- [SOLUTION.md](./SOLUTION.md) - Quick reference for all issues
- [CLEANUP_GUIDE.md](./CLEANUP_GUIDE.md) - Complete cleanup procedures

---

## Recommended Order of Operations

1. ✅ Run `./fix-rds-deletion.sh` (10-15 min wait)
2. ✅ Run `./fix-vpc-deletion.sh vpc-0f67b69c39640293b`
3. ✅ Clean up Terraform state if needed
4. ✅ Re-run aws-nuke
5. ✅ Manually delete remaining CloudWatch anomaly detectors if needed

The VPC should delete successfully after these steps!

