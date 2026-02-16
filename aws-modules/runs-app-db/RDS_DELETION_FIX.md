# RDS Cluster Deletion Protection Error - Quick Fix

## Error Message
```
Error: deleting RDS Cluster (runs-app-prod-aurora-pg): operation error RDS: DeleteDBCluster, 
https response error StatusCode: 400, RequestID: c5efe1b5-f512-49d8-b64b-f6f1bc46cc29, 
api error InvalidParameterCombination: Cannot delete protected Cluster, please disable 
deletion protection and try again.
```

## Root Cause
The Aurora RDS cluster has **deletion protection enabled**. This is a safety feature that prevents accidental deletion.

## Quick Fix (Choose One)

### Option 1: Bash Script (Recommended)
```bash
cd /Users/sathishjayapal/IdeaProjects/iAC-NikeRuns/aws-modules/runs-app-db
./fix-rds-deletion.sh
```

### Option 2: Python Script (More Control)
```bash
cd /Users/sathishjayapal/IdeaProjects/iAC-NikeRuns/aws-modules/runs-app-db

# Dry run first
python3 fix-rds-deletion.py --dry-run

# Actual deletion
python3 fix-rds-deletion.py

# With final snapshot (recommended for production)
python3 fix-rds-deletion.py --keep-snapshot
```

### Option 3: AWS Console
1. Go to **RDS Console** → **Databases**
2. Select `runs-app-prod-aurora-pg`
3. Click **Modify**
4. Scroll to **Deletion protection** → Uncheck
5. Click **Continue** → **Apply immediately** → **Modify DB Cluster**
6. Wait ~1 minute for modification to complete
7. Select the cluster → **Actions** → **Delete**
8. Follow the deletion prompts

### Option 4: AWS CLI Commands
```bash
# 1. Disable deletion protection
aws rds modify-db-cluster \
    --db-cluster-identifier runs-app-prod-aurora-pg \
    --no-deletion-protection \
    --apply-immediately \
    --region us-east-1

# 2. Wait a moment for the change to apply
sleep 10

# 3. Delete instances first
aws rds delete-db-instance \
    --db-instance-identifier runs-app-prod-writer-1 \
    --skip-final-snapshot \
    --region us-east-1

# 4. Wait for instances to be deleted
aws rds wait db-instance-deleted \
    --db-instance-identifier runs-app-prod-writer-1 \
    --region us-east-1

# 5. Delete the cluster
aws rds delete-db-cluster \
    --db-cluster-identifier runs-app-prod-aurora-pg \
    --skip-final-snapshot \
    --region us-east-1

# 6. Wait for cluster to be deleted
aws rds wait db-cluster-deleted \
    --db-cluster-identifier runs-app-prod-aurora-pg \
    --region us-east-1
```

## What the Scripts Do

The scripts will:
1. ✅ Check current cluster status
2. ✅ Disable deletion protection on the cluster
3. ✅ Find and delete all cluster instances (writer/reader)
4. ✅ Wait for instances to be deleted
5. ✅ Delete the cluster
6. ✅ Wait for cluster deletion to complete

## Expected Timeline

- Disabling protection: **~30 seconds**
- Deleting instances: **5-10 minutes**
- Deleting cluster: **2-5 minutes**
- **Total: ~10-15 minutes**

## Verification

After running the fix, verify deletion:

```bash
# Should return "DBClusterNotFoundFault"
aws rds describe-db-clusters \
    --db-cluster-identifier runs-app-prod-aurora-pg \
    --region us-east-1
```

## Important Notes

⚠️  **Data Loss Warning**: Deleting the cluster will permanently delete all data unless you create a final snapshot.

💡 **To Keep Data**: Use the `--keep-snapshot` flag with the Python script:
```bash
python3 fix-rds-deletion.py --keep-snapshot
```

## If Using Terraform

If you're managing this with Terraform, you have two options:

### Option A: Update Terraform First (Cleanest)
```hcl
# In your terraform.tfvars or module call
deletion_protection = false
```

Then run:
```bash
terraform apply  # Disables protection
terraform destroy  # Deletes cluster
```

### Option B: Use Script, Then Fix Terraform State
```bash
# 1. Run the fix script
./fix-rds-deletion.sh

# 2. Remove from Terraform state
terraform state rm aws_rds_cluster.this
terraform state rm aws_rds_cluster_instance.writer
```

## Troubleshooting

### "Cluster not found"
✅ Already deleted - you're good to go!

### "InvalidDBClusterStateFault"
⏳ Cluster is being modified. Wait 1-2 minutes and try again.

### "Access Denied"
🔐 Ensure your AWS credentials have RDS permissions:
- `rds:ModifyDBCluster`
- `rds:DeleteDBCluster`
- `rds:DeleteDBInstance`
- `rds:DescribeDBClusters`
- `rds:DescribeDBInstances`

### Script hangs on "Waiting..."
⏰ This is normal! Instance/cluster deletion can take 10-15 minutes. The script will wait automatically.

To check progress manually:
```bash
aws rds describe-db-clusters \
    --db-cluster-identifier runs-app-prod-aurora-pg \
    --region us-east-1 \
    --query 'DBClusters[0].Status'
```

## Prevention

To avoid this issue in the future:

1. **Set deletion_protection = false** in your Terraform for non-production environments
2. **Use Terraform destroy** instead of manual deletion
3. **For production**: Keep deletion protection enabled, but have a documented procedure for removal

## Related Files

- `fix-rds-deletion.sh` - Bash script for quick deletion
- `fix-rds-deletion.py` - Python script with more features
- `main.tf` - Terraform configuration with deletion_protection setting
- `CLEANUP_GUIDE.md` - General cleanup documentation

