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

## Summary of Files

| File | Purpose |
|------|---------|
| `quick-fix-sns.sh` | Fast SNS cleanup |
| `fix-rds-deletion.sh` | RDS deletion fix (bash) |
| `fix-rds-deletion.py` | RDS deletion fix (python) |
| `cleanup-budget-resources.py` | Complete budget cleanup |
| `RDS_DELETION_FIX.md` | RDS deletion detailed guide |
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

