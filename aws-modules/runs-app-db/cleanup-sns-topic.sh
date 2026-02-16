#!/bin/bash

################################################################################
# SNS Topic Cleanup Script
# Purpose: Remove all subscriptions and policies from SNS topic to allow deletion
# Usage: ./cleanup-sns-topic.sh <topic-arn>
################################################################################

set -e

# Check if topic ARN is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <topic-arn>"
    echo "Example: $0 arn:aws:sns:us-east-1:381636780001:runs-app-prod-db-budget-alerts"
    exit 1
fi

TOPIC_ARN="$1"
REGION=$(echo "$TOPIC_ARN" | cut -d':' -f4)

echo "=========================================="
echo "Cleaning up SNS Topic: $TOPIC_ARN"
echo "Region: $REGION"
echo "=========================================="

# Step 1: List and remove all subscriptions
echo ""
echo "Step 1: Listing subscriptions..."
SUBSCRIPTIONS=$(aws sns list-subscriptions-by-topic \
    --topic-arn "$TOPIC_ARN" \
    --region "$REGION" \
    --query 'Subscriptions[*].SubscriptionArn' \
    --output text 2>/dev/null || echo "")

if [ -n "$SUBSCRIPTIONS" ]; then
    echo "Found subscriptions. Removing..."
    for SUB_ARN in $SUBSCRIPTIONS; do
        if [ "$SUB_ARN" != "PendingConfirmation" ]; then
            echo "  Removing subscription: $SUB_ARN"
            aws sns unsubscribe \
                --subscription-arn "$SUB_ARN" \
                --region "$REGION" || echo "  Warning: Failed to remove subscription"
        else
            echo "  Skipping pending confirmation subscription"
        fi
    done
    echo "✓ All subscriptions removed"
else
    echo "✓ No subscriptions found"
fi

# Step 2: Remove topic policy
echo ""
echo "Step 2: Removing topic policy..."
aws sns set-topic-attributes \
    --topic-arn "$TOPIC_ARN" \
    --attribute-name Policy \
    --attribute-value "" \
    --region "$REGION" 2>/dev/null && echo "✓ Topic policy removed" || echo "✓ No topic policy found or already removed"

# Step 3: Attempt to delete the topic
echo ""
echo "Step 3: Attempting to delete topic..."
if aws sns delete-topic \
    --topic-arn "$TOPIC_ARN" \
    --region "$REGION" 2>/dev/null; then
    echo "✓ Topic successfully deleted!"
else
    echo "✗ Failed to delete topic. It may have dependencies or require manual intervention."
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check if there are any Lambda functions with permissions to this topic"
    echo "2. Check AWS Budgets configuration that might reference this topic"
    echo "3. Wait a few minutes and try again (AWS eventual consistency)"
    exit 1
fi

echo ""
echo "=========================================="
echo "Cleanup completed successfully!"
echo "=========================================="

