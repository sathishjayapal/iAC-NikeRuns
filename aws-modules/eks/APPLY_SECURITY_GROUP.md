# Applying NodePort Security Group to EC2 Instances

## Problem Solved

The initial configuration created the NodePort security group but didn't attach it to the worker node EC2 instances. This has been fixed by using a **Launch Template** that includes the security group.

## Changes Made

### 1. Launch Template Created
- **Resource**: `aws_launch_template.node_group`
- **Purpose**: Attach NodePort security group to all worker nodes
- **Security Group**: `sg-084ad3c23e2eb49ca` (sathish-eks-cluster-01-nodeport-sg)

### 2. Node Group Updated
- **Added**: `launch_template` block to reference the launch template
- **Effect**: All new worker nodes will automatically have the NodePort security group attached

### 3. Configuration Details

```hcl
resource "aws_launch_template" "node_group" {
  name_prefix = "sathish-eks-cluster-01-sathisheks-ng-1-workers-"
  description = "Launch template for sathish-eks-cluster-01 node group with NodePort security group"

  vpc_security_group_ids = [
    aws_security_group.nodeport.id  # sg-084ad3c23e2eb49ca
  ]
  
  # ... other configuration
}

resource "aws_eks_node_group" "workers" {
  # ... other configuration
  
  launch_template {
    id      = aws_launch_template.node_group.id
    version = "$Latest"
  }
}
```

## Validation Results

✅ **Terraform Validate**: Configuration is valid
✅ **Security Group Verified**: 
   - Name: `sathish-eks-cluster-01-nodeport-sg`
   - ID: `sg-084ad3c23e2eb49ca`
   - Ingress: TCP 30000-32767 from 0.0.0.0/0

✅ **Launch Template Plan**: Will be created with NodePort security group
✅ **Node Group Plan**: Will be replaced to use the launch template

## What Will Happen on Apply

### Resources to be Created
1. **Launch Template** - New launch template with NodePort security group

### Resources to be Replaced
1. **Node Group** - Will be destroyed and recreated with the launch template
   - ⚠️ **IMPORTANT**: This will cause **downtime** as nodes are replaced
   - Current nodes will be terminated
   - New nodes will be launched with the security group attached

### Plan Summary
```
Plan: 2 to add, 0 to change, 1 to destroy
```

## Impact Assessment

### ⚠️ DOWNTIME WARNING

Applying this change will:
1. **Destroy** the existing node group
2. **Terminate** all current worker nodes (2 nodes)
3. **Create** new worker nodes with the launch template
4. **Pods will be rescheduled** to new nodes

**Estimated Downtime**: 5-10 minutes (time for new nodes to join and become ready)

### Mitigation Strategies

#### Option 1: Blue-Green Deployment (Recommended for Production)
1. Create a new node group with a different name
2. Drain and cordon old nodes
3. Delete old node group
4. Zero downtime

#### Option 2: Accept Brief Downtime (Current Plan)
1. Run `terraform apply`
2. Wait for new nodes to be ready
3. Verify pods are running

#### Option 3: Manual Security Group Attachment (Temporary)
```bash
# Get current instance IDs
aws ec2 describe-instances \
  --filters "Name=tag:eks:nodegroup-name,Values=sathisheks-ng-1-workers" \
  --query 'Reservations[*].Instances[*].[InstanceId]' \
  --output text

# Attach security group to each instance
aws ec2 modify-instance-attribute \
  --instance-id i-xxxxxxxxx \
  --groups sg-084ad3c23e2eb49ca sg-<existing-sg-id>
```

## Verification After Apply

### 1. Check Node Group Status
```bash
aws eks describe-nodegroup \
  --cluster-name sathish-eks-cluster-01 \
  --nodegroup-name sathisheks-ng-1-workers \
  --query 'nodegroup.status'
```

### 2. Verify Security Groups on Instances
```bash
# Get instance IDs
INSTANCES=$(aws ec2 describe-instances \
  --filters "Name=tag:eks:nodegroup-name,Values=sathisheks-ng-1-workers" \
  --query 'Reservations[*].Instances[*].[InstanceId]' \
  --output text)

# Check security groups
for instance in $INSTANCES; do
  echo "Instance: $instance"
  aws ec2 describe-instances \
    --instance-ids $instance \
    --query 'Reservations[0].Instances[0].SecurityGroups[*].[GroupId,GroupName]' \
    --output table
done
```

### 3. Test NodePort Access
```bash
# Deploy a test service
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginx-test
  labels:
    app: nginx
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-nodeport
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF

# Get node public IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')

# Test access
curl http://$NODE_IP:30080
```

## Outputs Available

After applying, you'll have access to:

```bash
terraform output nodeport_security_group_id
terraform output nodeport_security_group_arn
terraform output launch_template_id
terraform output launch_template_latest_version
```

## Apply Command

When ready to proceed:

```bash
# Review the plan one more time
terraform plan

# Apply with auto-approve (use with caution)
terraform apply -auto-approve

# Or apply with confirmation
terraform apply
```

## Rollback Plan

If issues occur after applying:

```bash
# Revert to previous state
terraform state pull > backup.tfstate
terraform apply -target=aws_eks_node_group.workers

# Or destroy and recreate
terraform destroy -target=aws_eks_node_group.workers
terraform apply
```

## Production Recommendations

For production environments:

1. **Use Blue-Green Deployment**: Create new node group before destroying old one
2. **Restrict CIDR Blocks**: Update `nodeport_cidr_blocks` to specific IP ranges
3. **Use Load Balancer**: Prefer ALB/NLB over NodePort for production services
4. **Enable Monitoring**: Set up CloudWatch alarms for node health
5. **Test in Staging**: Apply changes to staging environment first
6. **Schedule Maintenance Window**: Plan the update during low-traffic periods

## Next Steps

1. ✅ Configuration validated
2. ⏳ Review impact assessment
3. ⏳ Choose deployment strategy
4. ⏳ Apply changes: `terraform apply`
5. ⏳ Verify security groups attached
6. ⏳ Test NodePort connectivity
7. ⏳ Update CIDR blocks for production
