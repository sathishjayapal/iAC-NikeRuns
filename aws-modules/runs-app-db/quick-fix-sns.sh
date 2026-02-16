#!/bin/bash

################################################################################
# Quick SNS Topic Fix for aws-nuke
# This script removes the blocking dependencies from the SNS topic
################################################################################

set -e

TOPIC_ARN="arn:aws:sns:us-east-1:381636780001:runs-app-prod-db-budget-alerts"
REGION="us-east-1"
ACCOUNT_ID="381636780001"
PREFIX="runs-app-prod"

echo "=========================================="
echo "Quick SNS Topic Cleanup"
echo "This will remove subscriptions to allow aws-nuke to proceed"
echo "=========================================="

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI is not installed or not in PATH"
    echo "Please install it first: https://aws.amazon.com/cli/"
    exit 1
fi

echo ""
echo "Step 1: Removing all SNS subscriptions..."
echo "=========================================="

# Get subscriptions and remove them
SUBS=$(aws sns list-subscriptions-by-topic \
    --topic-arn "$TOPIC_ARN" \
    --region "$REGION" \
    --query 'Subscriptions[*].[SubscriptionArn,Protocol,Endpoint]' \
    --output text 2>&1)

if echo "$SUBS" | grep -q "NotFound\|does not exist"; then
    echo "✓ Topic not found - may already be deleted"
    exit 0
fi

echo "$SUBS" | while IFS=$'\t' read -r SUB_ARN PROTOCOL ENDPOINT; do
    if [ "$SUB_ARN" = "PendingConfirmation" ]; then
        echo "  ⚠ Skipping pending confirmation subscription"
        continue
    fi

    if [ -n "$SUB_ARN" ] && [ "$SUB_ARN" != "None" ]; then
        echo "  Removing $PROTOCOL subscription..."
        if aws sns unsubscribe \
            --subscription-arn "$SUB_ARN" \
            --region "$REGION" 2>&1; then
            echo "  ✓ Removed"
        else
            echo "  ✗ Failed (may already be removed)"
        fi
    fi
done

echo ""
echo "Step 2: Removing topic policy..."
echo "=========================================="

if aws sns set-topic-attributes \
    --topic-arn "$TOPIC_ARN" \
    --attribute-name Policy \
    --attribute-value "" \
    --region "$REGION" 2>&1; then
    echo "✓ Topic policy removed"
else
    echo "⚠ Could not remove policy (may not exist)"
fi

echo ""
echo "Step 3: Waiting for AWS to propagate changes..."
echo "=========================================="
sleep 3
echo "✓ Ready"

echo ""
echo "=========================================="
echo "✅ SNS topic is now ready for deletion"
echo ""
echo "Next steps:"
echo "1. Re-run aws-nuke - the SNS topic should now be deleted"
echo "2. If it still fails, wait 2-3 minutes and try again"
echo ""
echo "To manually delete the topic:"
echo "  aws sns delete-topic --topic-arn $TOPIC_ARN --region $REGION"
echo "=========================================="

