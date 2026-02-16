# Budget Guardrail Resources Cleanup Guide

## Overview

This guide helps you clean up the budget guardrail resources created by the `runs-app-db` Terraform module. These resources include SNS topics, Lambda functions, IAM roles, and AWS Budgets that were set up to monitor and enforce cost limits.

## Problem

When trying to delete AWS resources (e.g., using aws-nuke or manual deletion), the SNS topic `runs-app-prod-db-budget-alerts` may fail to delete because it has dependencies:

```
us-east-1 - SNSTopic - TopicARN: arn:aws:sns:us-east-1:381636780001:runs-app-prod-db-budget-alerts
Status: waiting for removal
```

## Why This Happens

The SNS topic cannot be deleted because it has:
1. **Active subscriptions** (Lambda function, email addresses)
2. **Topic policies** attached
3. **References from AWS Budgets**
4. **Lambda permissions** referencing the topic

## Resources Created by Budget Guardrail

When `enable_budget_guardrail = true`, the following resources are created:

| Resource Type | Name Pattern | Purpose |
|--------------|--------------|---------|
| SNS Topic | `{prefix}-db-budget-alerts` | Receives budget notifications |
| SNS Subscriptions | Multiple | Lambda + email notifications |
| SNS Topic Policy | Attached to topic | Allows AWS Budgets to publish |
| Lambda Function | `{prefix}-budget-shutdown` | Stops DB or blocks access |
| IAM Role | `{prefix}-budget-shutdown-lambda-role` | Lambda execution role |
| IAM Policy | Inline policy | Lambda permissions |
| Lambda Permission | Statement ID: AllowExecutionFromBudgetSns | SNS invoke permission |
| AWS Budget | `{prefix}-runs-app-db-monthly` | Cost monitoring |

## Cleanup Solutions

### Option 1: Automated Python Script (Recommended)

Use the comprehensive Python cleanup script:

```bash
# Dry run first to see what will be deleted
python3 cleanup-budget-resources.py \
    --prefix runs-app-prod \
    --region us-east-1 \
    --dry-run

# Actual cleanup
python3 cleanup-budget-resources.py \
    --prefix runs-app-prod \
    --region us-east-1
```

**Requirements:**
- Python 3.6+
- boto3 library: `pip install boto3`
- AWS credentials configured (via AWS CLI or environment variables)
- Appropriate IAM permissions (see below)

### Option 2: Bash Script (Simple)

Use the bash script for just the SNS topic:

```bash
./cleanup-sns-topic.sh arn:aws:sns:us-east-1:381636780001:runs-app-prod-db-budget-alerts
```

**Requirements:**
- AWS CLI installed and configured
- jq (optional, for better output formatting)

### Option 3: Manual AWS Console Cleanup

Follow these steps in order:

1. **Remove SNS Subscriptions:**
   - Go to SNS → Topics → `runs-app-prod-db-budget-alerts`
   - Delete all subscriptions (Lambda and email)

2. **Remove Lambda Permission:**
   - Go to Lambda → Functions → `runs-app-prod-budget-shutdown`
   - Configuration → Permissions → Resource-based policy statements
   - Remove the SNS permission

3. **Delete AWS Budget:**
   - Go to Billing → Budgets
   - Delete `runs-app-prod-runs-app-db-monthly`

4. **Delete Lambda Function:**
   - Go to Lambda → Functions
   - Delete `runs-app-prod-budget-shutdown`

5. **Delete IAM Role:**
   - Go to IAM → Roles
   - Delete `runs-app-prod-budget-shutdown-lambda-role`

6. **Delete SNS Topic:**
   - Go to SNS → Topics
   - Delete `runs-app-prod-db-budget-alerts`

### Option 4: AWS CLI Commands

```bash
REGION="us-east-1"
ACCOUNT_ID="381636780001"
PREFIX="runs-app-prod"
TOPIC_ARN="arn:aws:sns:${REGION}:${ACCOUNT_ID}:${PREFIX}-db-budget-alerts"

# 1. List and remove subscriptions
aws sns list-subscriptions-by-topic \
    --topic-arn "${TOPIC_ARN}" \
    --region "${REGION}" \
    --query 'Subscriptions[*].SubscriptionArn' \
    --output text | while read SUB_ARN; do
    if [ "$SUB_ARN" != "PendingConfirmation" ]; then
        aws sns unsubscribe --subscription-arn "$SUB_ARN" --region "${REGION}"
    fi
done

# 2. Remove Lambda permission
aws lambda remove-permission \
    --function-name "${PREFIX}-budget-shutdown" \
    --statement-id "AllowExecutionFromBudgetSns" \
    --region "${REGION}"

# 3. Delete budget
aws budgets delete-budget \
    --account-id "${ACCOUNT_ID}" \
    --budget-name "${PREFIX}-runs-app-db-monthly"

# 4. Delete Lambda function
aws lambda delete-function \
    --function-name "${PREFIX}-budget-shutdown" \
    --region "${REGION}"

# 5. Delete IAM role policies
aws iam delete-role-policy \
    --role-name "${PREFIX}-budget-shutdown-lambda-role" \
    --policy-name "${PREFIX}-budget-shutdown-lambda-policy"

# 6. Delete IAM role
aws iam delete-role \
    --role-name "${PREFIX}-budget-shutdown-lambda-role"

# 7. Delete SNS topic
aws sns delete-topic \
    --topic-arn "${TOPIC_ARN}" \
    --region "${REGION}"
```

## Required IAM Permissions

To run the cleanup scripts, you need the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sns:ListSubscriptionsByTopic",
        "sns:Unsubscribe",
        "sns:DeleteTopic",
        "sns:SetTopicAttributes",
        "lambda:GetFunction",
        "lambda:GetPolicy",
        "lambda:RemovePermission",
        "lambda:DeleteFunction",
        "iam:ListRolePolicies",
        "iam:DeleteRolePolicy",
        "iam:DeleteRole",
        "budgets:DeleteBudget",
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
```

## Troubleshooting

### Issue: "Topic has pending subscriptions"
**Solution:** Wait 2-3 minutes after removing subscriptions, then try again. AWS uses eventual consistency.

### Issue: "Lambda permission not found"
**Solution:** The permission may already be removed. Continue with the next step.

### Issue: "Access Denied" errors
**Solution:** Ensure you have the required IAM permissions listed above.

### Issue: Budget still exists after deletion
**Solution:** AWS Budgets can take up to 5 minutes to fully delete. Wait and retry.

### Issue: Topic still referenced by aws-nuke
**Solution:** 
1. Ensure all subscriptions are removed
2. Clear the topic policy: `aws sns set-topic-attributes --topic-arn <arn> --attribute-name Policy --attribute-value ""`
3. Wait 2-3 minutes for AWS to propagate changes
4. Try aws-nuke again

## Prevention

To avoid this issue in the future:

### Option 1: Use Terraform to Destroy
```bash
terraform destroy -target=module.runs_app_db
```

### Option 2: Disable Budget Guardrail First
Before running aws-nuke, update your Terraform:

```hcl
module "runs_app_db" {
  source = "./aws-modules/runs-app-db"
  
  # Disable budget guardrail
  enable_budget_guardrail = false
  
  # ... other variables
}
```

Then apply:
```bash
terraform apply
```

This will remove all budget-related resources cleanly.

## Verification

After cleanup, verify all resources are deleted:

```bash
# Check SNS topic
aws sns get-topic-attributes \
    --topic-arn arn:aws:sns:us-east-1:381636780001:runs-app-prod-db-budget-alerts \
    --region us-east-1
# Should return: "NotFound"

# Check Lambda function
aws lambda get-function \
    --function-name runs-app-prod-budget-shutdown \
    --region us-east-1
# Should return: "ResourceNotFoundException"

# Check IAM role
aws iam get-role \
    --role-name runs-app-prod-budget-shutdown-lambda-role
# Should return: "NoSuchEntity"

# Check budget
aws budgets describe-budget \
    --account-id 381636780001 \
    --budget-name runs-app-prod-runs-app-db-monthly
# Should return: "NotFoundException"
```

## Support

If you encounter issues:

1. Check the AWS CloudWatch Logs for any error messages
2. Verify your AWS credentials and permissions
3. Ensure you're using the correct region and prefix
4. Try the manual cleanup steps in the AWS Console

## Related Files

- `main.tf` - Main Terraform configuration with budget guardrail resources
- `cleanup-sns-topic.sh` - Simple bash cleanup script
- `cleanup-budget-resources.py` - Comprehensive Python cleanup script

