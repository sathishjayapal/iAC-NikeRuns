# CloudWatch Anomaly Detector Deletion Fix

## Problem
```
us-east-1 - CloudWatchAnomalyDetector - Invocations - [MetricName: "Invocations"] - waiting for removal
```

## Quick Fix

```bash
cd /Users/sathishjayapal/IdeaProjects/iAC-NikeRuns/aws-modules/runs-app-db
./fix-cloudwatch-anomaly-detector.sh
```

## What It Does
1. Lists all CloudWatch Anomaly Detectors in us-east-1
2. Attempts to delete the Lambda Invocations detector with various stats
3. Tries to delete all other anomaly detectors found
4. Verifies deletion completed

## Manual Deletion (if script fails)

### Method 1: Simple Delete

```bash
# Most common case - Lambda Invocations with Average stat
aws cloudwatch delete-anomaly-detector \
    --namespace AWS/Lambda \
    --metric-name Invocations \
    --stat Average \
    --region us-east-1
```

### Method 2: With Dimensions (if associated with specific Lambda)

```bash
# If the detector is for a specific Lambda function
aws cloudwatch delete-anomaly-detector \
    --namespace AWS/Lambda \
    --metric-name Invocations \
    --stat Average \
    --dimensions Name=FunctionName,Value=runs-app-prod-budget-shutdown \
    --region us-east-1
```

### Method 3: Try All Stats

```bash
# Try different statistical aggregations
for STAT in Average Sum SampleCount Maximum Minimum; do
    echo "Trying $STAT..."
    aws cloudwatch delete-anomaly-detector \
        --namespace AWS/Lambda \
        --metric-name Invocations \
        --stat "$STAT" \
        --region us-east-1 2>&1 && echo "✅ Deleted with $STAT" || echo "⚠️  Not found with $STAT"
done
```

## Find Exact Parameters

If none of the above work, get the exact parameters:

```bash
# List all anomaly detectors with full details
aws cloudwatch describe-anomaly-detectors \
    --region us-east-1 \
    --output json > anomaly-detectors.json

# View the file
cat anomaly-detectors.json | jq '.'

# Or in table format
aws cloudwatch describe-anomaly-detectors \
    --region us-east-1 \
    --output table
```

Look for the output like:
```json
{
  "AnomalyDetectors": [
    {
      "Namespace": "AWS/Lambda",
      "MetricName": "Invocations",
      "Dimensions": [
        {
          "Name": "FunctionName",
          "Value": "runs-app-prod-budget-shutdown"
        }
      ],
      "Stat": "Average",
      "Configuration": { ... }
    }
  ]
}
```

Then delete with exact parameters:
```bash
aws cloudwatch delete-anomaly-detector \
    --namespace "AWS/Lambda" \
    --metric-name "Invocations" \
    --stat "Average" \
    --dimensions Name=FunctionName,Value=runs-app-prod-budget-shutdown \
    --region us-east-1
```

## AWS Console Method

If AWS CLI doesn't work:

1. Open **AWS Console** → **CloudWatch**
2. Left menu → **Anomaly detection**
3. Find the anomaly detector for "Invocations"
4. Click on it → **Actions** → **Delete**
5. Confirm deletion

## Why This Happens

CloudWatch Anomaly Detectors are created when:
- You enable anomaly detection for a Lambda function metric
- You use CloudWatch Insights or AWS Cost Anomaly Detection
- Automatic detection is enabled for certain metrics

The detector may have been created for the Lambda function `runs-app-prod-budget-shutdown` which was part of the budget guardrail.

## Verification

After deletion:

```bash
# Should return empty list
aws cloudwatch describe-anomaly-detectors \
    --region us-east-1 \
    --query 'AnomalyDetectors[*].[Namespace,MetricName,Stat]' \
    --output table
```

## Troubleshooting

### Error: "ResourceNotFoundException"
✅ Already deleted - you're good!

### Error: "InvalidParameterValue"
The dimensions don't match. Use `describe-anomaly-detectors` to get exact parameters.

### Error: "ValidationException"
You might be missing required dimensions. Check the full detector details.

### Detector Still Shows in aws-nuke
Wait 2-3 minutes for AWS to propagate the deletion, then re-run aws-nuke.

## After Deletion

Re-run aws-nuke:
```bash
aws-nuke -c nuke-config.yml --no-dry-run
```

The CloudWatch Anomaly Detector should now be removed!

## Related Files
- [SOLUTION.md](./SOLUTION.md) - Quick reference for all issues
- [VPC_DELETION_FIX.md](./VPC_DELETION_FIX.md) - VPC deletion guide
- [RDS_DELETION_FIX.md](./RDS_DELETION_FIX.md) - RDS deletion guide

## Common Detector Namespaces

If you have detectors from other services:

| Namespace | Metric Examples |
|-----------|-----------------|
| AWS/Lambda | Invocations, Errors, Duration, Throttles |
| AWS/RDS | CPUUtilization, DatabaseConnections |
| AWS/EC2 | CPUUtilization, NetworkIn, NetworkOut |
| AWS/ECS | CPUUtilization, MemoryUtilization |
| AWS/DynamoDB | ConsumedReadCapacityUnits, ConsumedWriteCapacityUnits |

Replace `AWS/Lambda` with the appropriate namespace in the deletion commands.

