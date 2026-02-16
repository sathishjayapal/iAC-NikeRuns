#!/usr/bin/env python3
"""
RDS Cluster Deletion Fix Script
Purpose: Disable deletion protection and delete the Aurora RDS cluster
Usage: python3 fix-rds-deletion.py --cluster runs-app-prod-aurora-pg --region us-east-1
"""

import argparse
import boto3
import sys
import time
from typing import Optional


def wait_with_progress(description: str, wait_time: int = 5):
    """Display a progress indicator while waiting"""
    print(f"⏳ {description}", end="", flush=True)
    for _ in range(wait_time):
        time.sleep(1)
        print(".", end="", flush=True)
    print(" ✓")


def check_cluster_exists(rds_client, cluster_id: str) -> bool:
    """Check if the cluster exists"""
    try:
        response = rds_client.describe_db_clusters(DBClusterIdentifier=cluster_id)
        cluster = response['DBClusters'][0]
        status = cluster['Status']
        deletion_protection = cluster['DeletionProtection']

        print(f"   Status: {status}")
        print(f"   Deletion Protection: {deletion_protection}")
        return True
    except rds_client.exceptions.DBClusterNotFoundFault:
        print("   ⚠️  Cluster not found (may already be deleted)")
        return False
    except Exception as e:
        print(f"   ❌ Error checking cluster: {e}")
        return False


def disable_deletion_protection(rds_client, cluster_id: str) -> bool:
    """Disable deletion protection on the cluster"""
    print("\n🔓 Disabling deletion protection on cluster...")
    print("=" * 80)

    try:
        rds_client.modify_db_cluster(
            DBClusterIdentifier=cluster_id,
            DeletionProtection=False,
            ApplyImmediately=True
        )
        print("   ✅ Deletion protection disabled")
        wait_with_progress("   Waiting for modification to apply", 5)
        return True
    except Exception as e:
        print(f"   ⚠️  Could not disable deletion protection: {e}")
        return False


def get_cluster_instances(rds_client, cluster_id: str) -> list:
    """Get all instances in the cluster"""
    print("\n📋 Checking for cluster instances...")
    print("=" * 80)

    try:
        response = rds_client.describe_db_instances(
            Filters=[
                {
                    'Name': 'db-cluster-id',
                    'Values': [cluster_id]
                }
            ]
        )
        instances = [inst['DBInstanceIdentifier'] for inst in response['DBInstances']]

        if instances:
            print(f"   Found {len(instances)} instance(s): {', '.join(instances)}")
        else:
            print("   ✅ No instances found")

        return instances
    except Exception as e:
        print(f"   ⚠️  Error getting instances: {e}")
        return []


def delete_instance(rds_client, instance_id: str) -> bool:
    """Delete a DB instance"""
    print(f"\n🗑️  Deleting instance: {instance_id}")
    print("=" * 80)

    try:
        rds_client.delete_db_instance(
            DBInstanceIdentifier=instance_id,
            SkipFinalSnapshot=True
        )
        print(f"   ✅ Deletion initiated for {instance_id}")
        return True
    except Exception as e:
        print(f"   ❌ Failed to delete instance: {e}")
        return False


def wait_for_instance_deletion(rds_client, instance_id: str, max_wait: int = 600):
    """Wait for instance to be deleted"""
    print(f"\n⏳ Waiting for instance {instance_id} to be deleted...")
    print("   This may take several minutes...")

    try:
        waiter = rds_client.get_waiter('db_instance_deleted')
        waiter.wait(
            DBInstanceIdentifier=instance_id,
            WaiterConfig={
                'Delay': 30,
                'MaxAttempts': max_wait // 30
            }
        )
        print(f"   ✅ Instance {instance_id} deleted")
        return True
    except Exception as e:
        print(f"   ⚠️  Wait timeout or error: {e}")
        print("   Deletion may still be in progress")
        return False


def delete_cluster(rds_client, cluster_id: str, skip_snapshot: bool = True) -> bool:
    """Delete the DB cluster"""
    print(f"\n🗑️  Deleting cluster: {cluster_id}")
    print("=" * 80)

    try:
        params = {
            'DBClusterIdentifier': cluster_id,
            'SkipFinalSnapshot': skip_snapshot
        }

        if not skip_snapshot:
            params['FinalDBSnapshotIdentifier'] = f"{cluster_id}-final-snapshot-{int(time.time())}"

        rds_client.delete_db_cluster(**params)
        print(f"   ✅ Cluster deletion initiated")
        return True
    except Exception as e:
        print(f"   ❌ Failed to delete cluster: {e}")
        return False


def wait_for_cluster_deletion(rds_client, cluster_id: str, max_wait: int = 600):
    """Wait for cluster to be deleted"""
    print(f"\n⏳ Waiting for cluster {cluster_id} to be deleted...")
    print("   This may take several minutes...")

    try:
        waiter = rds_client.get_waiter('db_cluster_deleted')
        waiter.wait(
            DBClusterIdentifier=cluster_id,
            WaiterConfig={
                'Delay': 30,
                'MaxAttempts': max_wait // 30
            }
        )
        print(f"   ✅ Cluster {cluster_id} deleted successfully")
        return True
    except Exception as e:
        print(f"   ⚠️  Wait timeout or error: {e}")
        print("   Deletion may still be in progress")
        return False


def main():
    parser = argparse.ArgumentParser(
        description='Fix RDS cluster deletion by disabling protection and deleting cluster'
    )
    parser.add_argument(
        '--cluster',
        default='runs-app-prod-aurora-pg',
        help='RDS cluster identifier (default: runs-app-prod-aurora-pg)'
    )
    parser.add_argument(
        '--region',
        default='us-east-1',
        help='AWS region (default: us-east-1)'
    )
    parser.add_argument(
        '--keep-snapshot',
        action='store_true',
        help='Create a final snapshot before deletion'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be done without actually doing it'
    )

    args = parser.parse_args()

    print("=" * 80)
    print("RDS Cluster Deletion Protection Fix")
    print("=" * 80)
    print(f"Cluster: {args.cluster}")
    print(f"Region: {args.region}")
    print(f"Skip Final Snapshot: {not args.keep_snapshot}")
    print(f"Dry Run: {args.dry_run}")
    print("=" * 80)

    if args.dry_run:
        print("\n⚠️  DRY RUN MODE - No changes will be made\n")

    # Initialize AWS client
    try:
        rds_client = boto3.client('rds', region_name=args.region)
        sts_client = boto3.client('sts', region_name=args.region)
        account_id = sts_client.get_caller_identity()['Account']
        print(f"\n🔍 AWS Account ID: {account_id}")
    except Exception as e:
        print(f"\n❌ Error initializing AWS clients: {e}")
        print("Make sure AWS credentials are configured")
        return 1

    # Step 1: Check cluster exists
    print("\n🔍 Checking cluster status...")
    print("=" * 80)
    if not check_cluster_exists(rds_client, args.cluster):
        return 0

    if args.dry_run:
        print("\n📋 Dry run completed. No changes made.")
        print("\nTo actually delete the cluster, run without --dry-run flag")
        return 0

    # Step 2: Disable deletion protection
    if not disable_deletion_protection(rds_client, args.cluster):
        print("\n⚠️  Warning: Could not disable deletion protection")
        print("Attempting to continue anyway...")

    # Step 3: Get and delete instances
    instances = get_cluster_instances(rds_client, args.cluster)

    for instance in instances:
        if delete_instance(rds_client, instance):
            wait_for_instance_deletion(rds_client, instance)

    # Step 4: Delete cluster
    if delete_cluster(rds_client, args.cluster, skip_snapshot=not args.keep_snapshot):
        wait_for_cluster_deletion(rds_client, args.cluster)
    else:
        print("\n❌ Failed to delete cluster")
        return 1

    # Step 5: Verify deletion
    print("\n✅ Deletion process completed!")
    print("=" * 80)
    print("\nVerification command:")
    print(f"  aws rds describe-db-clusters \\")
    print(f"    --db-cluster-identifier {args.cluster} \\")
    print(f"    --region {args.region}")
    print("\nShould return: DBClusterNotFoundFault")
    print("=" * 80)

    return 0


if __name__ == '__main__':
    sys.exit(main())

