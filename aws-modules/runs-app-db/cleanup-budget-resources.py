#!/usr/bin/env python3
"""
Budget Resources Cleanup Script
Purpose: Clean up all resources associated with the runs-app budget guardrail
         including SNS topic, subscriptions, Lambda function, and budget
Usage: python3 cleanup-budget-resources.py --prefix runs-app-prod --region us-east-1
"""

import argparse
import boto3
import sys
from typing import List, Optional


def cleanup_sns_subscriptions(sns_client, topic_arn: str) -> int:
    """Remove all subscriptions from an SNS topic"""
    print(f"\n📧 Cleaning up SNS subscriptions for: {topic_arn}")

    try:
        response = sns_client.list_subscriptions_by_topic(TopicArn=topic_arn)
        subscriptions = response.get('Subscriptions', [])

        if not subscriptions:
            print("   ✓ No subscriptions found")
            return 0

        count = 0
        for sub in subscriptions:
            sub_arn = sub.get('SubscriptionArn')
            protocol = sub.get('Protocol')
            endpoint = sub.get('Endpoint')

            if sub_arn == 'PendingConfirmation':
                print(f"   ⚠ Skipping pending confirmation subscription ({protocol})")
                continue

            print(f"   Removing {protocol} subscription to {endpoint}...")
            try:
                sns_client.unsubscribe(SubscriptionArn=sub_arn)
                count += 1
                print(f"   ✓ Removed subscription: {sub_arn[:50]}...")
            except Exception as e:
                print(f"   ✗ Failed to remove subscription: {e}")

        print(f"   ✓ Removed {count} subscription(s)")
        return count

    except Exception as e:
        print(f"   ✗ Error listing subscriptions: {e}")
        return 0


def cleanup_lambda_permissions(lambda_client, function_name: str, topic_arn: str) -> bool:
    """Remove Lambda permissions for SNS topic"""
    print(f"\n🔧 Removing Lambda permissions for: {function_name}")

    try:
        # Check if function exists
        try:
            lambda_client.get_function(FunctionName=function_name)
        except lambda_client.exceptions.ResourceNotFoundException:
            print(f"   ⚠ Lambda function not found (may already be deleted)")
            return True

        # Get function policy
        try:
            policy_response = lambda_client.get_policy(FunctionName=function_name)
            print(f"   Removing statement: AllowExecutionFromBudgetSns")
            lambda_client.remove_permission(
                FunctionName=function_name,
                StatementId='AllowExecutionFromBudgetSns'
            )
            print(f"   ✓ Lambda permission removed")
            return True
        except lambda_client.exceptions.ResourceNotFoundException:
            print(f"   ✓ No policy found (already removed)")
            return True

    except Exception as e:
        print(f"   ✗ Error removing Lambda permission: {e}")
        return False


def cleanup_lambda_function(lambda_client, function_name: str) -> bool:
    """Delete Lambda function"""
    print(f"\n🗑️  Deleting Lambda function: {function_name}")

    try:
        lambda_client.delete_function(FunctionName=function_name)
        print(f"   ✓ Lambda function deleted")
        return True
    except lambda_client.exceptions.ResourceNotFoundException:
        print(f"   ⚠ Lambda function not found (may already be deleted)")
        return True
    except Exception as e:
        print(f"   ✗ Error deleting Lambda function: {e}")
        return False


def cleanup_iam_role(iam_client, role_name: str) -> bool:
    """Delete IAM role and its policies"""
    print(f"\n🔐 Deleting IAM role: {role_name}")

    try:
        # First, delete inline policies
        try:
            response = iam_client.list_role_policies(RoleName=role_name)
            for policy_name in response.get('PolicyNames', []):
                print(f"   Deleting inline policy: {policy_name}")
                iam_client.delete_role_policy(RoleName=role_name, PolicyName=policy_name)
                print(f"   ✓ Inline policy deleted")
        except iam_client.exceptions.NoSuchEntityException:
            pass

        # Delete the role
        iam_client.delete_role(RoleName=role_name)
        print(f"   ✓ IAM role deleted")
        return True

    except iam_client.exceptions.NoSuchEntityException:
        print(f"   ⚠ IAM role not found (may already be deleted)")
        return True
    except Exception as e:
        print(f"   ✗ Error deleting IAM role: {e}")
        return False


def cleanup_budget(budgets_client, account_id: str, budget_name: str) -> bool:
    """Delete AWS Budget"""
    print(f"\n💰 Deleting budget: {budget_name}")

    try:
        budgets_client.delete_budget(
            AccountId=account_id,
            BudgetName=budget_name
        )
        print(f"   ✓ Budget deleted")
        return True
    except budgets_client.exceptions.NotFoundException:
        print(f"   ⚠ Budget not found (may already be deleted)")
        return True
    except Exception as e:
        print(f"   ✗ Error deleting budget: {e}")
        return False


def cleanup_sns_topic(sns_client, topic_arn: str) -> bool:
    """Delete SNS topic"""
    print(f"\n📢 Deleting SNS topic: {topic_arn}")

    try:
        sns_client.delete_topic(TopicArn=topic_arn)
        print(f"   ✓ SNS topic deleted")
        return True
    except Exception as e:
        print(f"   ✗ Error deleting SNS topic: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description='Clean up AWS budget guardrail resources for runs-app database'
    )
    parser.add_argument(
        '--prefix',
        default='runs-app-prod',
        help='Name prefix for resources (default: runs-app-prod)'
    )
    parser.add_argument(
        '--region',
        default='us-east-1',
        help='AWS region (default: us-east-1)'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be deleted without actually deleting'
    )

    args = parser.parse_args()

    prefix = args.prefix
    region = args.region

    print("=" * 80)
    print(f"AWS Budget Guardrail Cleanup Script")
    print(f"Prefix: {prefix}")
    print(f"Region: {region}")
    print(f"Dry Run: {args.dry_run}")
    print("=" * 80)

    if args.dry_run:
        print("\n⚠️  DRY RUN MODE - No resources will be deleted\n")

    # Initialize AWS clients
    sns_client = boto3.client('sns', region_name=region)
    lambda_client = boto3.client('lambda', region_name=region)
    iam_client = boto3.client('iam', region_name=region)
    budgets_client = boto3.client('budgets', region_name=region)
    sts_client = boto3.client('sts', region_name=region)

    # Get account ID
    account_id = sts_client.get_caller_identity()['Account']
    print(f"\n🔍 AWS Account ID: {account_id}")

    # Resource names
    topic_arn = f"arn:aws:sns:{region}:{account_id}:{prefix}-db-budget-alerts"
    lambda_function_name = f"{prefix}-budget-shutdown"
    iam_role_name = f"{prefix}-budget-shutdown-lambda-role"
    budget_name = f"{prefix}-runs-app-db-monthly"

    if args.dry_run:
        print("\n📋 Resources that would be deleted:")
        print(f"   - SNS Topic: {topic_arn}")
        print(f"   - Lambda Function: {lambda_function_name}")
        print(f"   - IAM Role: {iam_role_name}")
        print(f"   - Budget: {budget_name}")
        return 0

    # Cleanup order is important - dependencies first!
    success = True

    # 1. Remove SNS subscriptions (including Lambda)
    cleanup_sns_subscriptions(sns_client, topic_arn)

    # 2. Remove Lambda permissions
    if not cleanup_lambda_permissions(lambda_client, lambda_function_name, topic_arn):
        success = False

    # 3. Delete budget (which references SNS topic)
    if not cleanup_budget(budgets_client, account_id, budget_name):
        success = False

    # 4. Delete Lambda function
    if not cleanup_lambda_function(lambda_client, lambda_function_name):
        success = False

    # 5. Delete IAM role
    if not cleanup_iam_role(iam_client, iam_role_name):
        success = False

    # 6. Finally, delete SNS topic
    if not cleanup_sns_topic(sns_client, topic_arn):
        success = False

    print("\n" + "=" * 80)
    if success:
        print("✅ Cleanup completed successfully!")
    else:
        print("⚠️  Cleanup completed with some errors. Check output above.")
    print("=" * 80)

    return 0 if success else 1


if __name__ == '__main__':
    sys.exit(main())

