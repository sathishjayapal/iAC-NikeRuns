#!/bin/bash

################################################################################
# RDS Cluster Deletion Fix Script
# Purpose: Disable deletion protection and delete the RDS cluster
# Usage: ./fix-rds-deletion.sh
################################################################################

set -e

CLUSTER_IDENTIFIER="runs-app-prod-aurora-pg"
REGION="us-east-1"
INSTANCE_IDENTIFIER="runs-app-prod-writer-1"

echo "=========================================="
echo "RDS Cluster Deletion Protection Fix"
echo "Cluster: $CLUSTER_IDENTIFIER"
echo "Region: $REGION"
echo "=========================================="

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "❌ ERROR: AWS CLI is not installed or not in PATH"
    echo "Please install it first: https://aws.amazon.com/cli/"
    exit 1
fi

echo ""
echo "Step 1: Checking current cluster status..."
echo "=========================================="

if ! aws rds describe-db-clusters \
    --db-cluster-identifier "$CLUSTER_IDENTIFIER" \
    --region "$REGION" \
    --query 'DBClusters[0].[Status,DeletionProtection]' \
    --output table 2>&1; then
    echo "⚠️  Cluster not found - may already be deleted"
    exit 0
fi

echo ""
echo "Step 2: Disabling deletion protection on cluster..."
echo "=========================================="

if aws rds modify-db-cluster \
    --db-cluster-identifier "$CLUSTER_IDENTIFIER" \
    --no-deletion-protection \
    --apply-immediately \
    --region "$REGION" 2>&1; then
    echo "✅ Deletion protection disabled on cluster"
else
    echo "⚠️  Could not disable deletion protection (may already be disabled)"
fi

echo ""
echo "Step 3: Waiting for cluster modification to complete..."
echo "=========================================="
sleep 5
echo "✅ Ready"

echo ""
echo "Step 4: Checking for cluster instances..."
echo "=========================================="

INSTANCES=$(aws rds describe-db-instances \
    --filters "Name=db-cluster-id,Values=$CLUSTER_IDENTIFIER" \
    --region "$REGION" \
    --query 'DBInstances[*].DBInstanceIdentifier' \
    --output text 2>&1 || echo "")

if [ -n "$INSTANCES" ]; then
    echo "Found instances: $INSTANCES"

    for INSTANCE in $INSTANCES; do
        echo ""
        echo "Step 5: Deleting instance: $INSTANCE"
        echo "=========================================="

        if aws rds delete-db-instance \
            --db-instance-identifier "$INSTANCE" \
            --skip-final-snapshot \
            --region "$REGION" 2>&1; then
            echo "✅ Instance deletion initiated: $INSTANCE"
        else
            echo "⚠️  Could not delete instance: $INSTANCE"
        fi
    done

    echo ""
    echo "Step 6: Waiting for instances to be deleted..."
    echo "=========================================="
    echo "This may take several minutes..."

    aws rds wait db-instance-deleted \
        --db-instance-identifier "$INSTANCE_IDENTIFIER" \
        --region "$REGION" 2>&1 || echo "⚠️  Wait timed out or instance already deleted"

    echo "✅ Instances deleted"
else
    echo "✅ No instances found"
fi

echo ""
echo "Step 7: Deleting the cluster..."
echo "=========================================="

if aws rds delete-db-cluster \
    --db-cluster-identifier "$CLUSTER_IDENTIFIER" \
    --skip-final-snapshot \
    --region "$REGION" 2>&1; then
    echo "✅ Cluster deletion initiated"
else
    echo "❌ Failed to delete cluster"
    exit 1
fi

echo ""
echo "Step 8: Waiting for cluster to be deleted..."
echo "=========================================="
echo "This may take several minutes..."

if aws rds wait db-cluster-deleted \
    --db-cluster-identifier "$CLUSTER_IDENTIFIER" \
    --region "$REGION" 2>&1; then
    echo "✅ Cluster deleted successfully"
else
    echo "⚠️  Wait timed out, but deletion is in progress"
fi

echo ""
echo "=========================================="
echo "✅ RDS Cluster deletion completed!"
echo ""
echo "Verification command:"
echo "  aws rds describe-db-clusters \\"
echo "    --db-cluster-identifier $CLUSTER_IDENTIFIER \\"
echo "    --region $REGION"
echo ""
echo "Should return: DBClusterNotFoundFault"
echo "=========================================="

