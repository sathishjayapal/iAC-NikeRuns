# EKS Cost Optimization Guide

## Quick Cost-Saving Commands

### Option 1: Scale Down to Minimum (Recommended for Dev/Test)

Keep the cluster running but scale down to minimal resources:

```bash
# Scale down node group to 1 node (minimum for cluster operation)
aws eks update-nodegroup-config \
  --cluster-name <cluster-name> \
  --nodegroup-name <nodegroup-name> \
  --scaling-config minSize=1,maxSize=1,desiredSize=1 \
  --region us-east-1

# Or using kubectl to scale down deployments
kubectl scale deployment sathish-config-server --replicas=0
kubectl scale deployment <other-deployment> --replicas=0

# Delete ingresses to remove ALBs (costs ~$16-20/month per ALB)
kubectl delete ingress --all

# Keep services but they won't cost anything without pods
```

**Monthly Cost:** ~$73/month (1 t3.medium node + EKS control plane)

### Option 2: Stop Everything (Cheapest - Only EKS Control Plane)

```bash
# Scale node group to 0 (stops all worker nodes)
aws eks update-nodegroup-config \
  --cluster-name <cluster-name> \
  --nodegroup-name <nodegroup-name> \
  --scaling-config minSize=0,maxSize=3,desiredSize=0 \
  --region us-east-1

# Delete all ingresses (removes ALBs)
kubectl delete ingress --all
```

**Monthly Cost:** ~$73/month (EKS control plane only)
**Note:** Cluster remains configured, just no worker nodes running

### Option 3: Complete Cleanup (No Costs)

```bash
# Delete all ingresses first (important!)
kubectl delete ingress --all

# Wait for ALBs to be deleted (2-3 minutes)
sleep 180

# Destroy everything with Terraform
cd /Users/skminfotech/IdeaProjects/iAC-NikeRuns/aws-modules/eks
terraform destroy
```

**Monthly Cost:** $0
**Note:** You'll need to redeploy everything from scratch

## Cost Breakdown

### Current Setup Costs (Approximate)

| Resource | Monthly Cost |
|----------|--------------|
| EKS Control Plane | $73 |
| t3.medium nodes (3x) | ~$90 ($30 each) |
| Application Load Balancer | ~$16-20 |
| Data Transfer | ~$5-10 |
| EBS Volumes (80GB x 3) | ~$24 |
| **Total** | **~$208-227/month** |

### Optimized Costs

| Scenario | Monthly Cost | What's Running |
|----------|--------------|----------------|
| **Minimal (1 node)** | ~$73-93 | EKS + 1 worker node, no ALB |
| **Scaled to 0** | ~$73 | EKS control plane only |
| **Fully deleted** | $0 | Nothing |

## Recommended: Minimal Running Setup

This keeps your cluster alive but minimizes costs:

```bash
#!/bin/bash
# save as: scale-down.sh

echo "Scaling down to minimal configuration..."

# Delete all ingresses (removes ALBs)
echo "Deleting ingresses..."
kubectl delete ingress --all

# Wait for ALBs to be removed
echo "Waiting for ALBs to be deleted..."
sleep 180

# Scale deployments to 0 replicas
echo "Scaling down deployments..."
kubectl scale deployment --all --replicas=0

# Scale node group to 1
echo "Scaling node group to 1..."
aws eks update-nodegroup-config \
  --cluster-name eks-cluster-dotsky \
  --nodegroup-name ng-dotsky \
  --scaling-config minSize=1,maxSize=1,desiredSize=1 \
  --region us-east-1

echo "Done! Cluster scaled down to minimal configuration."
echo "Monthly cost: ~$93 (EKS + 1 t3.medium node)"
```

## Quick Scale-Up Script

When you need to work again:

```bash
#!/bin/bash
# save as: scale-up.sh

echo "Scaling up to working configuration..."

# Scale node group back to 3
echo "Scaling node group to 3..."
aws eks update-nodegroup-config \
  --cluster-name eks-cluster-dotsky \
  --nodegroup-name ng-dotsky \
  --scaling-config minSize=2,maxSize=3,desiredSize=3 \
  --region us-east-1

# Wait for nodes to be ready
echo "Waiting for nodes to be ready..."
sleep 120

# Scale deployments back up
echo "Scaling up deployments..."
kubectl scale deployment sathish-config-server --replicas=1

# Recreate ingresses
echo "Applying ingress configurations..."
kubectl apply -f /path/to/sathish-config-server-ing.yaml

echo "Done! Cluster scaled up and ready to use."
echo "Wait 2-3 minutes for ALB to be provisioned."
```

## Best Practice: Use Terraform Variables

Update your `terraform.tfvars` for different environments:

### Development (Minimal Cost)
```hcl
node_desired_capacity = 1
node_min_size        = 1
node_max_size        = 2
node_instance_type   = "t3.small"  # Even cheaper
enable_aws_load_balancer_controller = false  # Disable if not needed
```

### Production
```hcl
node_desired_capacity = 3
node_min_size        = 2
node_max_size        = 5
node_instance_type   = "t3.medium"
enable_aws_load_balancer_controller = true
```

## Cost-Saving Tips

### 1. Use Spot Instances (60-90% savings)
```bash
# Add to your node group configuration in Terraform
capacity_type = "SPOT"
```

### 2. Schedule Auto-Scaling
Use AWS Lambda to scale down during non-working hours:
- Scale to 0 nodes: 6 PM - 8 AM weekdays
- Scale to 0 nodes: All weekend
- **Potential savings:** ~60% of compute costs

### 3. Delete Unused Load Balancers
```bash
# List all load balancers
aws elbv2 describe-load-balancers --query 'LoadBalancers[*].[LoadBalancerName,LoadBalancerArn]' --output table

# Delete unused ALBs
kubectl delete ingress <ingress-name>
```

### 4. Use Fargate for Specific Workloads
Only pay for pods when they're running (no idle node costs).

### 5. Enable Cluster Autoscaler
Automatically scales nodes based on demand.

## Monitoring Costs

```bash
# Check current node count
kubectl get nodes

# Check running pods
kubectl get pods --all-namespaces

# List all load balancers
aws elbv2 describe-load-balancers --query 'LoadBalancers[*].LoadBalancerName'

# Check EBS volumes
aws ec2 describe-volumes --filters "Name=tag:kubernetes.io/cluster/<cluster-name>,Values=owned"
```

## Emergency Cost Stop

If costs are running away:

```bash
# Immediate stop - scale everything to 0
kubectl delete ingress --all
aws eks update-nodegroup-config \
  --cluster-name <cluster-name> \
  --nodegroup-name <nodegroup-name> \
  --scaling-config minSize=0,maxSize=0,desiredSize=0 \
  --region us-east-1

# Or nuclear option - destroy everything
terraform destroy -auto-approve
```

## Recommended Daily Workflow

### End of Day (5 minutes)
```bash
# Scale down to save costs overnight
./scale-down.sh
```

### Start of Day (5 minutes)
```bash
# Scale back up when you need to work
./scale-up.sh
```

**Savings:** ~$60-80/month by running only during work hours

## Cost Comparison

| Scenario | Hours/Month | Monthly Cost | Annual Cost |
|----------|-------------|--------------|-------------|
| **24/7 (3 nodes + ALB)** | 720 | $227 | $2,724 |
| **Work hours only (8h/day, 5 days/week)** | ~160 | $80 | $960 |
| **Minimal (1 node, no ALB)** | 720 | $93 | $1,116 |
| **Scaled to 0 (EKS only)** | 720 | $73 | $876 |

## Summary

**For Development/Learning (Recommended):**
```bash
# Use the minimal setup
- 1 worker node (t3.small)
- No ALB (use NodePort or port-forward)
- Scale to 0 when not using
- Monthly cost: ~$50-73
```

**Commands:**
```bash
# Minimal setup
terraform apply -var="node_desired_capacity=1" -var="node_instance_type=t3.small"

# When not using (scale to 0)
aws eks update-nodegroup-config --cluster-name <name> --nodegroup-name <name> \
  --scaling-config minSize=0,maxSize=1,desiredSize=0 --region us-east-1

# When you need it (scale to 1)
aws eks update-nodegroup-config --cluster-name <name> --nodegroup-name <name> \
  --scaling-config minSize=1,maxSize=1,desiredSize=1 --region us-east-1
```

This approach gives you a working cluster when needed while keeping costs minimal when idle.
