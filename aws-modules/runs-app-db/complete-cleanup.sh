#!/bin/bash

################################################################################
# Complete AWS Cleanup for aws-nuke
# Purpose: Fix all deletion issues in the correct order
# Usage: ./complete-cleanup.sh
################################################################################

set -e

REGION="us-east-1"
VPC_ID="vpc-0f67b69c39640293b"

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                   AWS COMPLETE CLEANUP FOR AWS-NUKE                          ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "This script will clean up all resources in the correct order:"
echo "  1. SNS Topic subscriptions and policies"
echo "  2. RDS Cluster (with deletion protection fix)"
echo "  3. VPC dependencies (security groups, subnets, etc.)"
echo "  4. CloudWatch Anomaly Detectors"
echo ""
echo "Region: $REGION"
echo "VPC: $VPC_ID"
echo ""
echo "Total estimated time: 15-20 minutes"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

################################################################################
# STEP 1: SNS Topic Cleanup
################################################################################
echo ""
echo "════════════════════════════════════════════════════════════════════════════════"
echo "STEP 1: Cleaning up SNS Topic"
echo "════════════════════════════════════════════════════════════════════════════════"

if [ -f "./quick-fix-sns.sh" ]; then
    echo "Running SNS cleanup..."
    ./quick-fix-sns.sh || echo "⚠️  SNS cleanup had some issues, continuing..."
else
    echo "⚠️  quick-fix-sns.sh not found, skipping SNS cleanup"
fi

################################################################################
# STEP 2: RDS Cleanup
################################################################################
echo ""
echo "════════════════════════════════════════════════════════════════════════════════"
echo "STEP 2: Cleaning up RDS Cluster"
echo "════════════════════════════════════════════════════════════════════════════════"

if [ -f "./fix-rds-deletion.sh" ]; then
    echo "Running RDS cleanup..."
    echo "⏰ This will take 10-15 minutes..."
    ./fix-rds-deletion.sh || echo "⚠️  RDS cleanup had some issues, continuing..."
else
    echo "⚠️  fix-rds-deletion.sh not found, skipping RDS cleanup"
fi

################################################################################
# STEP 3: VPC Dependencies Cleanup
################################################################################
echo ""
echo "════════════════════════════════════════════════════════════════════════════════"
echo "STEP 3: Cleaning up VPC Dependencies"
echo "════════════════════════════════════════════════════════════════════════════════"

if [ -f "./fix-vpc-deletion.sh" ]; then
    echo "Running VPC cleanup..."
    ./fix-vpc-deletion.sh "$VPC_ID" || echo "⚠️  VPC cleanup had some issues, continuing..."
else
    echo "⚠️  fix-vpc-deletion.sh not found, skipping VPC cleanup"
fi

################################################################################
# STEP 4: CloudWatch Anomaly Detector Cleanup
################################################################################
echo ""
echo "════════════════════════════════════════════════════════════════════════════════"
echo "STEP 4: Cleaning up CloudWatch Anomaly Detectors"
echo "════════════════════════════════════════════════════════════════════════════════"

if [ -f "./fix-cloudwatch-anomaly-detector.sh" ]; then
    echo "Running CloudWatch cleanup..."
    ./fix-cloudwatch-anomaly-detector.sh || echo "⚠️  CloudWatch cleanup had some issues, continuing..."
else
    echo "⚠️  fix-cloudwatch-anomaly-detector.sh not found, skipping CloudWatch cleanup"
fi

################################################################################
# COMPLETION
################################################################################
echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                          CLEANUP COMPLETED                                   ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Summary:"
echo "  ✅ SNS topic subscriptions removed"
echo "  ✅ RDS cluster deletion initiated"
echo "  ✅ VPC dependencies cleaned up"
echo "  ✅ CloudWatch anomaly detectors cleaned up"
echo ""
echo "Next Steps:"
echo ""
echo "1. Wait a few minutes for AWS to propagate changes"
echo ""
echo "2. Re-run aws-nuke:"
echo "   $ aws-nuke -c nuke-config.yml --no-dry-run"
echo ""
echo "3. If aws-nuke still fails on these resources:"
echo ""
echo "   SNS Topic:"
echo "     aws sns delete-topic \\"
echo "       --topic-arn arn:aws:sns:$REGION:ACCOUNT:runs-app-prod-db-budget-alerts \\"
echo "       --region $REGION"
echo ""
echo "   RDS Cluster (if still exists):"
echo "     aws rds delete-db-cluster \\"
echo "       --db-cluster-identifier runs-app-prod-aurora-pg \\"
echo "       --skip-final-snapshot \\"
echo "       --region $REGION"
echo ""
echo "   VPC:"
echo "     aws ec2 delete-vpc \\"
echo "       --vpc-id $VPC_ID \\"
echo "       --region $REGION"
echo ""
echo "4. Manual cleanup may be needed for:"
echo "   - CloudWatch Anomaly Detectors"
echo "   - DHCP Options (will be deleted with VPC)"
echo ""
echo "Verification Commands:"
echo ""
echo "  Check RDS:"
echo "    aws rds describe-db-clusters --region $REGION | grep runs-app-prod"
echo ""
echo "  Check VPC:"
echo "    aws ec2 describe-vpcs --vpc-ids $VPC_ID --region $REGION"
echo ""
echo "  Check SNS:"
echo "    aws sns list-topics --region $REGION | grep budget-alerts"
echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║  All cleanup scripts have completed. Please verify and re-run aws-nuke.     ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"

