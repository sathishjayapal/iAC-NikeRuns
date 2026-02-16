#!/bin/bash

################################################################################
# CloudWatch Anomaly Detector Cleanup Script
# Purpose: Delete CloudWatch Anomaly Detectors blocking aws-nuke
# Usage: ./fix-cloudwatch-anomaly-detector.sh
################################################################################

set -e

REGION="us-east-1"

echo "=========================================="
echo "CloudWatch Anomaly Detector Cleanup"
echo "Region: $REGION"
echo "=========================================="

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "❌ ERROR: AWS CLI is not installed or not in PATH"
    exit 1
fi

echo ""
echo "Step 1: Listing all CloudWatch Anomaly Detectors..."
echo "=========================================="

# List all anomaly detectors
DETECTORS=$(aws cloudwatch describe-anomaly-detectors \
    --region "$REGION" \
    --max-results 100 \
    --output json 2>&1)

if [ $? -ne 0 ]; then
    echo "❌ Failed to list anomaly detectors"
    echo "$DETECTORS"
    exit 1
fi

# Save to file for reference
echo "$DETECTORS" > /tmp/anomaly-detectors.json
echo "✅ Full detector list saved to /tmp/anomaly-detectors.json"

# Check if any detectors exist
DETECTOR_COUNT=$(echo "$DETECTORS" | jq '.AnomalyDetectors | length' 2>/dev/null || echo "0")

if [ "$DETECTOR_COUNT" -eq 0 ]; then
    echo "✅ No anomaly detectors found"
    exit 0
fi

echo "Found $DETECTOR_COUNT anomaly detector(s)"
echo ""

# Display detectors in readable format
echo "$DETECTORS" | jq -r '.AnomalyDetectors[] |
    "Namespace: \(.Namespace // "N/A"),
     MetricName: \(.MetricName // "N/A"),
     Stat: \(.Stat // "N/A"),
     Dimensions: \(.Dimensions // [] | map("\(.Name)=\(.Value)") | join(", "))"' 2>/dev/null || \
    echo "$DETECTORS"

echo ""
echo "Step 2: Deleting anomaly detectors..."
echo "=========================================="

# Method 1: Try to delete the Lambda Invocations detector specifically
echo "Attempting to delete Lambda Invocations detector..."

aws cloudwatch delete-anomaly-detector \
    --namespace "AWS/Lambda" \
    --metric-name "Invocations" \
    --stat "Average" \
    --region "$REGION" 2>&1 && echo "✅ Deleted Lambda/Invocations/Average detector" || \
    echo "⚠️  Could not delete with Average stat, trying other stats..."

# Try other common stats
for STAT in "Sum" "SampleCount" "Maximum" "Minimum"; do
    echo "Trying stat: $STAT"
    aws cloudwatch delete-anomaly-detector \
        --namespace "AWS/Lambda" \
        --metric-name "Invocations" \
        --stat "$STAT" \
        --region "$REGION" 2>&1 && echo "✅ Deleted Lambda/Invocations/$STAT detector" || \
        echo "⚠️  Detector with $STAT stat not found or already deleted"
done

echo ""
echo "Step 3: Attempting to delete all other detectors..."
echo "=========================================="

# Method 2: Parse JSON and delete each detector with exact parameters
if command -v jq &> /dev/null; then
    echo "$DETECTORS" | jq -c '.AnomalyDetectors[]' | while read -r detector; do
        NAMESPACE=$(echo "$detector" | jq -r '.Namespace // empty')
        METRIC_NAME=$(echo "$detector" | jq -r '.MetricName // empty')
        STAT=$(echo "$detector" | jq -r '.Stat // empty')

        if [ -n "$NAMESPACE" ] && [ -n "$METRIC_NAME" ] && [ -n "$STAT" ]; then
            echo "Deleting: $NAMESPACE / $METRIC_NAME / $STAT"

            # Build dimensions parameter if they exist
            DIMENSIONS=$(echo "$detector" | jq -r '.Dimensions // [] |
                map("Name=\(.Name),Value=\(.Value)") | join(" ")')

            if [ -n "$DIMENSIONS" ]; then
                aws cloudwatch delete-anomaly-detector \
                    --namespace "$NAMESPACE" \
                    --metric-name "$METRIC_NAME" \
                    --stat "$STAT" \
                    --dimensions $DIMENSIONS \
                    --region "$REGION" 2>&1 && echo "  ✅ Deleted" || echo "  ⚠️  Failed"
            else
                aws cloudwatch delete-anomaly-detector \
                    --namespace "$NAMESPACE" \
                    --metric-name "$METRIC_NAME" \
                    --stat "$STAT" \
                    --region "$REGION" 2>&1 && echo "  ✅ Deleted" || echo "  ⚠️  Failed"
            fi
        fi
    done
else
    echo "⚠️  jq not installed - cannot parse detectors automatically"
    echo "Please install jq or delete manually using the AWS Console"
fi

echo ""
echo "Step 4: Verifying deletion..."
echo "=========================================="

sleep 2

REMAINING=$(aws cloudwatch describe-anomaly-detectors \
    --region "$REGION" \
    --max-results 100 \
    --query 'AnomalyDetectors | length' \
    --output text 2>&1)

if [ "$REMAINING" -eq 0 ]; then
    echo "✅ All anomaly detectors deleted successfully!"
else
    echo "⚠️  $REMAINING anomaly detector(s) still remain"
    echo ""
    echo "Remaining detectors:"
    aws cloudwatch describe-anomaly-detectors \
        --region "$REGION" \
        --max-results 100 \
        --output table
fi

echo ""
echo "=========================================="
echo "CloudWatch Anomaly Detector cleanup completed"
echo ""
echo "If detectors still exist, you can:"
echo "1. Check the AWS Console: CloudWatch → Anomaly detection"
echo "2. Review /tmp/anomaly-detectors.json for exact parameters"
echo "3. Delete manually with exact dimensions"
echo ""
echo "Manual deletion example:"
echo "  aws cloudwatch delete-anomaly-detector \\"
echo "    --namespace AWS/Lambda \\"
echo "    --metric-name Invocations \\"
echo "    --stat Average \\"
echo "    --region $REGION"
echo ""
echo "With dimensions:"
echo "  aws cloudwatch delete-anomaly-detector \\"
echo "    --namespace AWS/Lambda \\"
echo "    --metric-name Invocations \\"
echo "    --stat Average \\"
echo "    --dimensions Name=FunctionName,Value=runs-app-prod-budget-shutdown \\"
echo "    --region $REGION"
echo "=========================================="

