#!/bin/bash

################################################################################
# VPC Cleanup Script for aws-nuke
# Purpose: Clean up VPC dependencies so aws-nuke can delete the VPC
# Usage: ./fix-vpc-deletion.sh vpc-0f67b69c39640293b
################################################################################

set -e

VPC_ID="${1:-vpc-0f67b69c39640293b}"
REGION="us-east-1"

echo "=========================================="
echo "VPC Cleanup for aws-nuke"
echo "VPC: $VPC_ID"
echo "Region: $REGION"
echo "=========================================="

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "❌ ERROR: AWS CLI is not installed or not in PATH"
    exit 1
fi

echo ""
echo "Step 1: Checking if VPC exists..."
echo "=========================================="

if ! aws ec2 describe-vpcs \
    --vpc-ids "$VPC_ID" \
    --region "$REGION" \
    --query 'Vpcs[0].[VpcId,CidrBlock,IsDefault]' \
    --output table 2>&1; then
    echo "⚠️  VPC not found - may already be deleted"
    exit 0
fi

echo ""
echo "Step 2: Cleaning up RDS instances in VPC..."
echo "=========================================="

# Find RDS instances in this VPC
RDS_INSTANCES=$(aws rds describe-db-instances \
    --region "$REGION" \
    --query "DBInstances[?DBSubnetGroup.VpcId=='$VPC_ID'].DBInstanceIdentifier" \
    --output text 2>&1 || echo "")

if [ -n "$RDS_INSTANCES" ]; then
    echo "Found RDS instances: $RDS_INSTANCES"
    for INSTANCE in $RDS_INSTANCES; do
        echo "  Deleting RDS instance: $INSTANCE"
        aws rds delete-db-instance \
            --db-instance-identifier "$INSTANCE" \
            --skip-final-snapshot \
            --region "$REGION" 2>&1 || echo "  ⚠️  Failed to delete $INSTANCE"
    done
else
    echo "✅ No RDS instances found in VPC"
fi

echo ""
echo "Step 3: Cleaning up RDS clusters in VPC..."
echo "=========================================="

# Find RDS clusters in this VPC
RDS_CLUSTERS=$(aws rds describe-db-clusters \
    --region "$REGION" \
    --query "DBClusters[?DBSubnetGroup=='runs-app-prod-db-subnets'].DBClusterIdentifier" \
    --output text 2>&1 || echo "")

if [ -n "$RDS_CLUSTERS" ]; then
    echo "Found RDS clusters: $RDS_CLUSTERS"
    for CLUSTER in $RDS_CLUSTERS; do
        # First disable deletion protection
        echo "  Disabling deletion protection on: $CLUSTER"
        aws rds modify-db-cluster \
            --db-cluster-identifier "$CLUSTER" \
            --no-deletion-protection \
            --apply-immediately \
            --region "$REGION" 2>&1 || echo "  ⚠️  Could not modify cluster"

        sleep 5

        echo "  Deleting RDS cluster: $CLUSTER"
        aws rds delete-db-cluster \
            --db-cluster-identifier "$CLUSTER" \
            --skip-final-snapshot \
            --region "$REGION" 2>&1 || echo "  ⚠️  Failed to delete $CLUSTER"
    done
else
    echo "✅ No RDS clusters found"
fi

echo ""
echo "Step 4: Deleting DB subnet groups..."
echo "=========================================="

DB_SUBNET_GROUPS=$(aws rds describe-db-subnet-groups \
    --region "$REGION" \
    --query "DBSubnetGroups[?VpcId=='$VPC_ID'].DBSubnetGroupName" \
    --output text 2>&1 || echo "")

if [ -n "$DB_SUBNET_GROUPS" ]; then
    for SG in $DB_SUBNET_GROUPS; do
        echo "  Deleting DB subnet group: $SG"
        aws rds delete-db-subnet-group \
            --db-subnet-group-name "$SG" \
            --region "$REGION" 2>&1 || echo "  ⚠️  Failed to delete $SG"
    done
    echo "✅ DB subnet groups deleted"
else
    echo "✅ No DB subnet groups found"
fi

echo ""
echo "Step 5: Deleting security groups..."
echo "=========================================="

# Get all non-default security groups in the VPC
SECURITY_GROUPS=$(aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --region "$REGION" \
    --query "SecurityGroups[?GroupName!='default'].GroupId" \
    --output text 2>&1 || echo "")

if [ -n "$SECURITY_GROUPS" ]; then
    echo "Found security groups: $SECURITY_GROUPS"

    # First, remove all ingress rules
    for SG in $SECURITY_GROUPS; do
        echo "  Removing ingress rules from: $SG"
        aws ec2 revoke-security-group-ingress \
            --group-id "$SG" \
            --region "$REGION" \
            --ip-permissions "$(aws ec2 describe-security-groups \
                --group-ids "$SG" \
                --region "$REGION" \
                --query 'SecurityGroups[0].IpPermissions' 2>/dev/null)" 2>&1 || echo "  No ingress rules to remove"
    done

    # Then remove egress rules
    for SG in $SECURITY_GROUPS; do
        echo "  Removing egress rules from: $SG"
        aws ec2 revoke-security-group-egress \
            --group-id "$SG" \
            --region "$REGION" \
            --ip-permissions "$(aws ec2 describe-security-groups \
                --group-ids "$SG" \
                --region "$REGION" \
                --query 'SecurityGroups[0].IpPermissionsEgress' 2>/dev/null)" 2>&1 || echo "  No egress rules to remove"
    done

    # Finally delete the security groups
    for SG in $SECURITY_GROUPS; do
        echo "  Deleting security group: $SG"
        aws ec2 delete-security-group \
            --group-id "$SG" \
            --region "$REGION" 2>&1 || echo "  ⚠️  Failed to delete $SG"
    done
    echo "✅ Security groups cleaned up"
else
    echo "✅ No custom security groups found"
fi

echo ""
echo "Step 6: Deleting subnets..."
echo "=========================================="

SUBNETS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --region "$REGION" \
    --query "Subnets[*].SubnetId" \
    --output text 2>&1 || echo "")

if [ -n "$SUBNETS" ]; then
    for SUBNET in $SUBNETS; do
        echo "  Deleting subnet: $SUBNET"
        aws ec2 delete-subnet \
            --subnet-id "$SUBNET" \
            --region "$REGION" 2>&1 || echo "  ⚠️  Failed to delete $SUBNET"
    done
    echo "✅ Subnets deleted"
else
    echo "✅ No subnets found"
fi

echo ""
echo "Step 7: Deleting internet gateways..."
echo "=========================================="

IGWS=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --region "$REGION" \
    --query "InternetGateways[*].InternetGatewayId" \
    --output text 2>&1 || echo "")

if [ -n "$IGWS" ]; then
    for IGW in $IGWS; do
        echo "  Detaching IGW: $IGW from VPC: $VPC_ID"
        aws ec2 detach-internet-gateway \
            --internet-gateway-id "$IGW" \
            --vpc-id "$VPC_ID" \
            --region "$REGION" 2>&1 || echo "  ⚠️  Failed to detach $IGW"

        echo "  Deleting IGW: $IGW"
        aws ec2 delete-internet-gateway \
            --internet-gateway-id "$IGW" \
            --region "$REGION" 2>&1 || echo "  ⚠️  Failed to delete $IGW"
    done
    echo "✅ Internet gateways deleted"
else
    echo "✅ No internet gateways found"
fi

echo ""
echo "Step 8: Deleting route tables..."
echo "=========================================="

ROUTE_TABLES=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --region "$REGION" \
    --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" \
    --output text 2>&1 || echo "")

if [ -n "$ROUTE_TABLES" ]; then
    for RT in $ROUTE_TABLES; do
        echo "  Deleting route table: $RT"
        aws ec2 delete-route-table \
            --route-table-id "$RT" \
            --region "$REGION" 2>&1 || echo "  ⚠️  Failed to delete $RT"
    done
    echo "✅ Route tables deleted"
else
    echo "✅ No custom route tables found"
fi

echo ""
echo "Step 9: Checking CloudWatch Anomaly Detectors..."
echo "=========================================="

echo "⚠️  CloudWatch Anomaly Detectors must be deleted manually or via aws-nuke"
echo "   Run: aws cloudwatch delete-anomaly-detector --help"

echo ""
echo "=========================================="
echo "✅ VPC cleanup preparation completed!"
echo ""
echo "Next steps:"
echo "1. Wait for any RDS deletions to complete (10-15 minutes)"
echo "2. Re-run aws-nuke - the VPC should now be deletable"
echo "3. If VPC still can't be deleted, check for:"
echo "   - Network interfaces"
echo "   - NAT gateways"
echo "   - VPN connections"
echo "   - VPC peering connections"
echo ""
echo "Manual VPC deletion command:"
echo "  aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION"
echo "=========================================="

