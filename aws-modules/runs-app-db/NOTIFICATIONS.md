# Budget Alert Notifications

This module includes an automated budget alert and shutdown system to prevent unexpected AWS costs.

## How It Works

```
AWS Budget Alert → SNS Topic → Lambda Function → Shutdown Action
                        ↓
                   Email Alerts (optional)
```

### Components

1. **AWS Budget**: Monitors RDS costs against a monthly limit (default: $5 USD)
2. **SNS Topic**: Receives notifications when budget threshold is exceeded (default: 100%)
3. **Lambda Function**: Automatically shuts down or blocks access to the database
4. **Email Notifications**: Optional email alerts to notify team members

## Configuration

### Basic Setup (Lambda Shutdown Only)

```terraform
module "runs_app_db" {
  source = "../../"
  
  name_prefix = "my-app-prod"
  vpc_id      = "vpc-xxxxx"
  subnet_ids  = ["subnet-xxxxx", "subnet-yyyyy"]
  
  # Budget guardrail enabled by default
  enable_budget_guardrail     = true
  monthly_budget_limit_usd    = 5
  budget_alert_threshold_percent = 100
  shutdown_mode               = "block_access"
}
```

### With Email Notifications

```terraform
module "runs_app_db" {
  source = "../../"
  
  name_prefix = "my-app-prod"
  vpc_id      = "vpc-xxxxx"
  subnet_ids  = ["subnet-xxxxx", "subnet-yyyyy"]
  
  # Budget configuration
  monthly_budget_limit_usd       = 10
  budget_alert_threshold_percent = 80  # Alert at 80% ($8)
  
  # Email notifications
  alert_email_addresses = [
    "devops@example.com",
    "alerts@example.com"
  ]
}
```

**Important**: Email subscribers will receive a confirmation email from AWS and must click the confirmation link before receiving alerts.

## Shutdown Modes

### `block_access` (Recommended)

Revokes all security group ingress rules, preventing any connections to the database.

**Pros:**
- Works with all RDS/Aurora types
- Immediate effect
- Database continues running (no downtime for recovery)

**Cons:**
- Still incurs compute costs
- Manual recovery required (re-add security group rules)

### `stop_db`

Stops the Aurora cluster completely.

**Pros:**
- Stops compute charges
- Clean shutdown

**Cons:**
- May not work with Aurora Serverless v2
- Longer recovery time (cluster must restart)
- May fail if cluster has deletion protection

## Testing the Notification System

### 1. Test SNS Topic

```bash
# Get the SNS topic ARN
terraform output budget_alerts_topic_arn

# Publish a test message
aws sns publish \
  --topic-arn "arn:aws:sns:us-east-1:xxxxxxxxxxxx:my-app-prod-db-budget-alerts" \
  --message "Test budget alert" \
  --subject "Budget Alert Test" \
  --region us-east-1
```

Expected result:
- Lambda function is invoked
- Email subscribers receive the message (if configured)

### 2. Test Lambda Function Directly

```bash
# Create test event
cat > test-event.json << 'EOF'
{
  "Records": [
    {
      "EventSource": "aws:sns",
      "Sns": {
        "Message": "Budget threshold exceeded - test"
      }
    }
  ]
}
EOF

# Invoke Lambda
aws lambda invoke \
  --function-name my-app-prod-budget-shutdown \
  --payload file://test-event.json \
  --region us-east-1 \
  response.json

# Check response
cat response.json
```

Expected output: `{"status": "ok", "shutdown_mode": "block_access"}`

### 3. View Lambda Logs

```bash
# Tail Lambda logs in real-time
aws logs tail /aws/lambda/my-app-prod-budget-shutdown --follow --region us-east-1

# Or filter recent events
aws logs filter-log-events \
  --log-group-name /aws/lambda/my-app-prod-budget-shutdown \
  --region us-east-1 \
  --start-time $(date -u -d '1 hour ago' +%s)000
```

### 4. Check Email Subscription Status

```bash
# List all subscriptions for the topic
aws sns list-subscriptions-by-topic \
  --topic-arn "$(terraform output -raw budget_alerts_topic_arn)" \
  --region us-east-1
```

Look for:
- Email subscriptions with `SubscriptionArn` (confirmed)
- Lambda subscription with `SubscriptionArn` (auto-confirmed)

## Troubleshooting

### Email Not Received

**Check 1**: Subscription confirmed?
```bash
aws sns list-subscriptions-by-topic \
  --topic-arn "$(terraform output -raw budget_alerts_topic_arn)" \
  --region us-east-1 | jq '.Subscriptions[] | select(.Protocol=="email")'
```

If `SubscriptionArn` is `"PendingConfirmation"`, check spam folder for confirmation email.

**Check 2**: Resend confirmation
```bash
# Delete and recreate the subscription
terraform taint 'module.runs_app_db.aws_sns_topic_subscription.budget_email_alerts["your-email@example.com"]'
terraform apply
```

### Lambda Not Triggering

**Check 1**: Lambda has permission to be invoked by SNS?
```bash
aws lambda get-policy \
  --function-name my-app-prod-budget-shutdown \
  --region us-east-1 | jq '.Policy | fromjson'
```

Should show SNS principal with `InvokeFunction` permission.

**Check 2**: Subscription exists?
```bash
terraform state show module.runs_app_db.aws_sns_topic_subscription.budget_shutdown_lambda[0]
```

**Check 3**: Test direct invocation
```bash
aws lambda invoke \
  --function-name my-app-prod-budget-shutdown \
  --payload '{"Records":[{"EventSource":"aws:sns","Sns":{"Message":"test"}}]}' \
  --region us-east-1 \
  /tmp/response.json && cat /tmp/response.json
```

### Budget Not Triggering

**Check 1**: Budget exists and is configured correctly?
```bash
aws budgets describe-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget-name my-app-prod-runs-app-db-monthly
```

**Check 2**: Current spending
```bash
aws ce get-cost-and-usage \
  --time-period Start=2026-02-01,End=2026-02-28 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter '{"Services":{"Key":"SERVICE","Values":["Amazon Relational Database Service"]}}'
```

**Note**: AWS Budgets can take up to 24 hours to trigger after threshold is exceeded.

## Recovery After Shutdown

### If `shutdown_mode = "block_access"`

Re-add security group rules to allow access:

```bash
# Get security group ID
SG_ID=$(terraform output -raw security_group_id)

# Add rule to allow access from your IP
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 5443 \
  --cidr "$(curl -s ifconfig.me)/32" \
  --region us-east-1

# Or from another security group
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 5443 \
  --source-group "sg-xxxxx" \
  --region us-east-1
```

### If `shutdown_mode = "stop_db"`

Start the cluster:

```bash
CLUSTER_ID=$(terraform output -raw cluster_id)
aws rds start-db-cluster --db-cluster-identifier "$CLUSTER_ID" --region us-east-1
```

## Variables Reference

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_budget_guardrail` | bool | `true` | Enable/disable budget alerts |
| `monthly_budget_limit_usd` | number | `5` | Monthly cost limit in USD |
| `budget_alert_threshold_percent` | number | `100` | Alert threshold (% of limit) |
| `shutdown_mode` | string | `"block_access"` | `"block_access"` or `"stop_db"` |
| `alert_email_addresses` | list(string) | `[]` | Email addresses for alerts |

## Outputs

| Output | Description |
|--------|-------------|
| `budget_name` | AWS Budget name |
| `budget_alerts_topic_arn` | SNS topic ARN |
| `email_alert_subscriptions` | List of email addresses subscribed |

## Best Practices

1. **Set conservative budgets** for dev/test environments
2. **Use multiple notification thresholds** (e.g., 50%, 80%, 100%)
3. **Add team email addresses** to catch issues early
4. **Test the shutdown mechanism** before relying on it
5. **Document recovery procedures** for your team
6. **Monitor Lambda logs** to ensure it's working
7. **Use `block_access`** mode for most scenarios (more reliable)

## Example: Multi-Threshold Alerts

For production, you may want multiple alert levels:

```terraform
# Budget with early warning (this module)
module "runs_app_db" {
  # ... basic config ...
  monthly_budget_limit_usd       = 100
  budget_alert_threshold_percent = 50  # First alert at $50
  alert_email_addresses          = ["devops@example.com"]
}

# Additional budget for critical alert (outside module)
resource "aws_budgets_budget" "critical_alert" {
  name         = "${var.name_prefix}-critical-alert"
  budget_type  = "COST"
  limit_amount = "100"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = 90
    threshold_type      = "PERCENTAGE"
    notification_type   = "ACTUAL"
    subscriber_email_addresses = [
      "critical-alerts@example.com",
      "manager@example.com"
    ]
  }
}
```

## Cost Considerations

The notification system itself has minimal cost:

- **SNS**: $0.50 per 1 million publishes (first 1,000 free)
- **Lambda**: First 1 million requests free, then $0.20/1M
- **AWS Budgets**: First 2 budgets free, then $0.02/day per budget

**Total**: Essentially free for typical usage.

The database itself will incur charges until shut down or deleted.

