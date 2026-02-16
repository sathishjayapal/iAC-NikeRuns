# runs-app-db Terraform module

Cost-first AWS Aurora PostgreSQL Serverless v2 module for `runs-app`, with optional budget guardrail automation.

## What this module creates

- Aurora PostgreSQL Serverless v2 cluster (`min_acu` to `max_acu`)
- Writer instance (`db.serverless`)
- DB subnet group and security group
- Secrets Manager secret for DB credentials
- Optional AWS Budget + SNS + Lambda guardrail to enforce budget-triggered shutdown behavior

## Budget guardrail behavior

This module supports a configurable budget threshold (`monthly_budget_limit_usd`) and action mode:

- `shutdown_mode = "stop_db"`: calls `rds:StopDBCluster`
- `shutdown_mode = "block_access"`: revokes all ingress rules on the DB security group

> AWS Budgets is not real-time and does not guarantee a hard cap. Cost metrics can lag by hours.

## Usage

```hcl
module "runs_app_db" {
  source = "../runs-app-db"

  name_prefix = "runs-app-prod"
  vpc_id      = "vpc-0123456789abcdef0"
  subnet_ids  = ["subnet-aaaa", "subnet-bbbb"]

  allowed_security_group_ids = ["sg-0123abcd4567efgh8"]

  min_acu = 0.5
  max_acu = 1

  enable_budget_guardrail         = true
  monthly_budget_limit_usd        = 5
  budget_alert_threshold_percent  = 100
  shutdown_mode                   = "block_access"

  tags = {
    Environment = "prod"
    Project     = "runs-app"
    Owner       = "platform"
  }
}
```

## Inputs (high-signal)

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `name_prefix` | string | yes | - | Resource naming prefix |
| `vpc_id` | string | yes | - | VPC ID for resources |
| `subnet_ids` | list(string) | yes | - | Subnet IDs for Aurora (3+ recommended) |
| `allowed_security_group_ids` | list(string) | no | `[]` | Security groups allowed to access DB |
| `allowed_cidr_blocks` | list(string) | no | `[]` | CIDR blocks allowed to access DB |
| `min_acu` | number | no | `0.5` | Minimum Aurora capacity units |
| `max_acu` | number | no | `1` | Maximum Aurora capacity units |
| `enable_budget_guardrail` | bool | no | `false` | Enable budget monitoring/enforcement |
| `monthly_budget_limit_usd` | number | no | `10` | Monthly budget limit in USD |
| `shutdown_mode` | string | no | `"stop_db"` | Budget enforcement: `stop_db` or `block_access` |
| `deletion_protection` | bool | no | `true` | Enable deletion protection |

## Outputs

| Name | Description |
|------|-------------|
| `cluster_endpoint` | Aurora cluster writer endpoint |
| `cluster_reader_endpoint` | Aurora cluster reader endpoint |
| `cluster_id` | Aurora cluster identifier |
| `db_name` | Database name |
| `secret_arn` | Secrets Manager ARN for credentials |

## Troubleshooting & Common Issues

### ❌ SNS Topic Won't Delete (aws-nuke stuck)

**Error**: SNS topic waiting for removal during cleanup

**Solution**:
```bash
cd aws-modules/runs-app-db
./quick-fix-sns.sh
```

📖 See [SOLUTION.md](./SOLUTION.md) for details

### ❌ RDS Cluster Deletion Protection Error

**Error**: `Cannot delete protected Cluster, please disable deletion protection`

**Solution**:
```bash
cd aws-modules/runs-app-db
./fix-rds-deletion.sh
```

📖 See [RDS_DELETION_FIX.md](./RDS_DELETION_FIX.md) for details

### 📚 Documentation Files

| File | Purpose |
|------|---------|
| [SOLUTION.md](./SOLUTION.md) | Quick reference for both SNS and RDS issues |
| [RDS_DELETION_FIX.md](./RDS_DELETION_FIX.md) | Detailed RDS deletion guide |
| [CLEANUP_GUIDE.md](./CLEANUP_GUIDE.md) | Comprehensive cleanup documentation |
| [NOTIFICATIONS.md](./NOTIFICATIONS.md) | Budget notification setup |

### 🛠️ Cleanup Scripts

| Script | Purpose |
|--------|---------|
| `quick-fix-sns.sh` | Quick SNS subscription cleanup |
| `fix-rds-deletion.sh` | Fix RDS deletion protection (bash) |
| `fix-rds-deletion.py` | Fix RDS deletion protection (python) |
| `cleanup-budget-resources.py` | Complete budget resources cleanup |
| `cleanup-sns-topic.sh` | Detailed SNS cleanup |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Aurora PostgreSQL Cluster                 │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │ Subnet AZ-1│  │ Subnet AZ-2│  │ Subnet AZ-3│            │
│  │            │  │            │  │            │            │
│  │ Writer     │  │ (standby)  │  │ (standby)  │            │
│  │ Instance   │  │            │  │            │            │
│  └────────────┘  └────────────┘  └────────────┘            │
│         │              │              │                      │
│         └──────────────┼──────────────┘                      │
│                        │                                     │
│                ┌───────▼────────┐                           │
│                │ Security Group │                           │
│                │  Port: 5432    │                           │
│                └────────────────┘                           │
└─────────────────────────────────────────────────────────────┘
                         │
                ┌────────▼────────┐
                │ Secrets Manager │
                │  DB Credentials │
                └─────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              Budget Guardrail (Optional)                     │
│                                                              │
│  ┌──────────┐     ┌──────────┐     ┌──────────────────┐   │
│  │ AWS      │ ──▶ │   SNS    │ ──▶ │ Lambda Function  │   │
│  │ Budget   │     │  Topic   │     │                  │   │
│  │          │     │          │     │ • Stop DB        │   │
│  │ Monitors │     │ Alerts   │     │ • Block Access   │   │
│  │ $$ Spend │     │          │     │                  │   │
│  └──────────┘     └────┬─────┘     └──────────────────┘   │
│                        │                                    │
│                   ┌────▼─────┐                             │
│                   │  Email   │                             │
│                   │  Alerts  │                             │
│                   └──────────┘                             │
└─────────────────────────────────────────────────────────────┘
```

## Best Practices

### For Production
- ✅ Enable `deletion_protection = true`
- ✅ Set appropriate `backup_retention_period` (7-35 days)
- ✅ Use `skip_final_snapshot = false`
- ✅ Configure `alert_email_addresses` for budget alerts
- ✅ Set realistic `min_acu` and `max_acu` based on workload
- ✅ Use private subnets only
- ✅ Restrict `allowed_security_group_ids` to application SGs only

### For Development/Testing
- Set `deletion_protection = false` for easier cleanup
- Use `skip_final_snapshot = true`
- Consider `min_acu = 0.5` to minimize costs
- Enable `budget_guardrail` with low limits for cost control

### Security
- Never set `allowed_cidr_blocks = ["0.0.0.0/0"]`
- Use Secrets Manager for credential access
- Enable encryption (default in this module)
- Use IAM database authentication when possible

## Cost Optimization

**Serverless v2 Pricing** (us-east-1):
- ACU hour: ~$0.12
- Storage: ~$0.10/GB-month
- I/O: ~$0.20/million requests

**Example Monthly Costs**:
- `min_acu=0.5, max_acu=1`: ~$44-88/month (0.5-1 ACU × 730 hours)
- `min_acu=0.5, max_acu=2`: ~$44-175/month
- Add ~$10/GB for storage

**Cost Control**:
1. Set appropriate `min_acu` (can be 0.5)
2. Enable budget guardrail with `shutdown_mode = "stop_db"`
3. Use Aurora Auto Scaling (automatic with serverless v2)
4. Schedule shutdown for non-production during off-hours

## Examples

See the [examples/](./examples/) directory for:
- Production setup with budget guardrail
- Development setup with minimal costs
- Multi-environment configuration

## License

This module is part of the runs-app infrastructure as code project.

- `name_prefix`: Resource naming prefix
- `vpc_id`, `subnet_ids`: Network placement
- `allowed_cidr_blocks`, `allowed_security_group_ids`: DB access controls
- `min_acu`, `max_acu`: Serverless scaling bounds
- `monthly_budget_limit_usd`: Customizable monthly threshold (USD)
- `shutdown_mode`: `stop_db` or `block_access`

## Outputs

- DB endpoints and identifiers
- DB security group ID
- Secrets Manager secret ARN
- Budget/SNS/Lambda identifiers when guardrail is enabled
