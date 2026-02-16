# AWS Resource Deletion Issues - Solutions

This document covers solutions for common deletion issues with the runs-app-db module.

---

## Issue 1: SNS Topic Deletion Blocked

### Problem
Your aws-nuke run is stuck waiting to remove this SNS topic:
```
arn:aws:sns:us-east-1:381636780001:runs-app-prod-db-budget-alerts
```

## Root Cause
The SNS topic was created by the Terraform budget guardrail feature and has dependencies:
- **2+ SNS subscriptions** (Lambda + email)
- **SNS topic policy** (allows AWS Budgets to publish)
- **Lambda function** with permissions referencing this topic
- **AWS Budget** that sends notifications to this topic

## Quick Solution (Run This Now)

```bash
cd /Users/sathishjayapal/IdeaProjects/iAC-NikeRuns/aws-modules/runs-app-db
./quick-fix-sns.sh
```

This script will:
1. ✅ Remove all SNS subscriptions
2. ✅ Remove the topic policy
3. ✅ Prepare the topic for deletion

Then **re-run aws-nuke** and the topic should be deleted.

## Alternative: Manual AWS Console Steps

1. **AWS SNS Console** → Topics → `runs-app-prod-db-budget-alerts`
   - Delete all subscriptions under "Subscriptions" tab
   
2. **Re-run aws-nuke**

## If Quick Fix Doesn't Work

Use the comprehensive cleanup:

```bash
# Install boto3 first (if using Python script)
pip install boto3

# Then run
cd /Users/sathishjayapal/IdeaProjects/iAC-NikeRuns/aws-modules/runs-app-db
python3 cleanup-budget-resources.py --prefix runs-app-prod --region us-east-1
```

This will clean up ALL related resources:
- SNS topic + subscriptions + policy
- Lambda function `runs-app-prod-budget-shutdown`
- IAM role `runs-app-prod-budget-shutdown-lambda-role`
- AWS Budget `runs-app-prod-runs-app-db-monthly`

## Files Created for You

| File | Purpose |
|------|---------|
| `quick-fix-sns.sh` | ⚡ Fast fix - removes SNS subscriptions/policy |
| `cleanup-sns-topic.sh` | 🔧 SNS topic cleanup only |
| `cleanup-budget-resources.py` | 🐍 Complete cleanup of all budget resources |
| `CLEANUP_GUIDE.md` | 📖 Detailed documentation |

## Understanding the Architecture

The budget guardrail creates this flow:

```
AWS Budget (monitoring costs)
    ↓ (when threshold exceeded)
SNS Topic (budget alerts)
    ↓ (notifications sent to)
    ├─→ Lambda Function (stops DB or blocks access)
    └─→ Email Addresses (alerts admins)
```

**To delete the SNS topic, you must break these connections first.**

## Prevention for Next Time

### Option 1: Use Terraform Destroy
```bash
terraform destroy -target=module.runs_app_db
```

### Option 2: Disable Budget Guardrail First
Edit your Terraform and set:
```hcl
enable_budget_guardrail = false
```

Then apply, which removes resources cleanly before aws-nuke.

## Verification After Cleanup

```bash
Should return error (not found).

---

## Issue 2: RDS Cluster Deletion Protection

### Problem
```
Error: deleting RDS Cluster (runs-app-prod-aurora-pg): operation error RDS: DeleteDBCluster,
api error InvalidParameterCombination: Cannot delete protected Cluster, please disable 
deletion protection and try again.
```

### Root Cause
The Aurora RDS cluster has **deletion protection enabled** - a safety feature preventing accidental deletion.

### Quick Solution (Run This Now)

```bash
cd /Users/sathishjayapal/IdeaProjects/iAC-NikeRuns/aws-modules/runs-app-db
./fix-rds-deletion.sh
```

**OR** use Python for more control:

```bash
# Dry run first to see what will happen
python3 fix-rds-deletion.py --dry-run

# Actual deletion
python3 fix-rds-deletion.py

# With final snapshot (recommended for production)
python3 fix-rds-deletion.py --keep-snapshot
```

### What It Does
1. Disables deletion protection on the cluster
2. Deletes all cluster instances (writer/reader)
3. Deletes the cluster
4. Waits for complete deletion (~10-15 minutes)

### Alternative: AWS Console
1. **RDS Console** → **Databases** → `runs-app-prod-aurora-pg`
2. **Modify** → Uncheck **Deletion protection**
3. **Apply immediately** → Wait ~1 minute
4. **Actions** → **Delete** → Follow prompts

### Verification
```bash
aws rds describe-db-clusters \
    --db-cluster-identifier runs-app-prod-aurora-pg \
    --region us-east-1
```
Should return: `DBClusterNotFoundFault`

📖 **See RDS_DELETION_FIX.md for detailed documentation**

---

## Issue 3: VPC Cannot Be Deleted

### Problem
```
us-east-1 - EC2VPC - vpc-0f67b69c39640293b - [tag:Name: "sathish-eks-VPC"] - failed
us-east-1 - EC2DHCPOption - dopt-ea048c90 - failed
us-east-1 - CloudWatchAnomalyDetector - Invocations - waiting for removal
```

### Root Cause
The VPC has **active dependencies** that must be removed first:
- RDS cluster and instances using DB subnet groups
- Security groups, subnets, route tables
- Internet gateway attached
- CloudWatch anomaly detectors
- Hardcoded VPC ID in Terraform example

### Quick Solution (Run This Now)

```bash
cd /Users/sathishjayapal/IdeaProjects/iAC-NikeRuns/aws-modules/runs-app-db

# Step 1: Delete RDS resources first (if not done already)
./fix-rds-deletion.sh

# Wait 10-15 minutes for RDS deletion

# Step 2: Clean up VPC dependencies
./fix-vpc-deletion.sh vpc-0f67b69c39640293b
```

### What It Does
1. Deletes RDS clusters and instances in the VPC
2. Removes DB subnet groups
3. Deletes security groups and their rules
4. Removes subnets, route tables, internet gateways
5. Prepares VPC for aws-nuke deletion

### Order Matters!
**You must delete in this order:**
1. RDS (10-15 min)
2. VPC dependencies (2-5 min)
3. Re-run aws-nuke

### CloudWatch Anomaly Detector
This may need manual deletion:
```bash
aws cloudwatch delete-anomaly-detector \
    --namespace AWS/Lambda \
    --metric-name Invocations \
    --stat Average \
    --region us-east-1
```

### Verification
```bash
aws ec2 describe-vpcs \
    --vpc-ids vpc-0f67b69c39640293b \
    --region us-east-1
```
Should return: `InvalidVpcID.NotFound`

📖 **See VPC_DELETION_FIX.md for detailed documentation**

---

## Issue 4: CloudWatch Anomaly Detector Stuck

### Problem
```
us-east-1 - CloudWatchAnomalyDetector - Invocations - [MetricName: "Invocations"] - waiting for removal
```

### Root Cause
CloudWatch Anomaly Detector was created for the Lambda function monitoring. This is likely associated with the `runs-app-prod-budget-shutdown` Lambda function.

### Quick Solution (Run This Now)

```bash
cd /Users/sathishjayapal/IdeaProjects/iAC-NikeRuns/aws-modules/runs-app-db
./fix-cloudwatch-anomaly-detector.sh
```

### Alternative: Manual Deletion

```bash
# Try the most common case
aws cloudwatch delete-anomaly-detector \
    --namespace AWS/Lambda \
    --metric-name Invocations \
    --stat Average \
    --region us-east-1

# If that fails, try with function dimension
aws cloudwatch delete-anomaly-detector \
    --namespace AWS/Lambda \
    --metric-name Invocations \
    --stat Average \
    --dimensions Name=FunctionName,Value=runs-app-prod-budget-shutdown \
    --region us-east-1
```

### Find Exact Parameters

```bash
# Get full details of all anomaly detectors
aws cloudwatch describe-anomaly-detectors \
    --region us-east-1 \
    --output json > /tmp/anomaly-detectors.json

# View them
cat /tmp/anomaly-detectors.json | jq '.'
```

### Verification
```bash
aws cloudwatch describe-anomaly-detectors \
    --region us-east-1 \
    --query 'AnomalyDetectors | length'
```
Should return: `0`

📖 **See CLOUDWATCH_ANOMALY_FIX.md for detailed documentation**

---

## Summary of Files

| File | Purpose |
|------|---------|
| `quick-fix-sns.sh` | Fast SNS cleanup |
| `fix-rds-deletion.sh` | RDS deletion fix (bash) |
| `fix-rds-deletion.py` | RDS deletion fix (python) |
| `fix-vpc-deletion.sh` | VPC cleanup for deletion |
| `fix-cloudwatch-anomaly-detector.sh` | CloudWatch anomaly detector cleanup |
| `complete-cleanup.sh` | Run all cleanups in correct order |
| `cleanup-budget-resources.py` | Complete budget cleanup |
| `RDS_DELETION_FIX.md` | RDS deletion detailed guide |
| `VPC_DELETION_FIX.md` | VPC deletion detailed guide |
| `CLOUDWATCH_ANOMALY_FIX.md` | CloudWatch anomaly detector guide |
| `CLEANUP_GUIDE.md` | Full cleanup documentation |
aws sns get-topic-attributes \
    --topic-arn arn:aws:sns:us-east-1:381636780001:runs-app-prod-db-budget-alerts \
    --region us-east-1
```

## Need Help?

See `CLEANUP_GUIDE.md` for:
- Detailed troubleshooting
- Required IAM permissions
- Step-by-step manual cleanup
- AWS CLI commands reference

