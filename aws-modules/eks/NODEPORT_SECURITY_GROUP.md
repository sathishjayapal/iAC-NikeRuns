# NodePort Security Group Configuration

## Overview

A dedicated security group has been created for Kubernetes NodePort services, allowing traffic on the standard NodePort range (30000-32767).

## Security Group Details

- **Name**: `sathish-eks-cluster-01-nodeport-sg`
- **VPC**: `vpc-0a1753e65db583cd6`
- **Purpose**: Allow external access to Kubernetes NodePort services

## Rules

### Ingress Rules
- **Port Range**: 30000-32767 (TCP)
- **Protocol**: TCP
- **Source**: 0.0.0.0/0 (configurable via `nodeport_cidr_blocks` variable)
- **Description**: NodePort range for Kubernetes services

### Egress Rules
- **Port Range**: All
- **Protocol**: All
- **Destination**: 0.0.0.0/0
- **Description**: Allow all outbound traffic

## Configuration

### Restrict Access (Recommended for Production)

To restrict NodePort access to specific IP ranges, update `terraform.tfvars`:

```hcl
# Restrict to specific CIDR blocks
nodeport_cidr_blocks = [
  "10.0.0.0/8",      # Internal network
  "203.0.113.0/24"   # Office IP range
]
```

### Allow from Anywhere (Development Only)

```hcl
# Allow from anywhere (default - use with caution)
nodeport_cidr_blocks = ["0.0.0.0/0"]
```

## Attaching to EC2 Instances

### Manual Attachment

After the security group is created, you can attach it to your worker nodes:

```bash
# Get the security group ID
terraform output nodeport_security_group_id

# Attach to EC2 instances via AWS Console or CLI
aws ec2 modify-instance-attribute \
  --instance-id i-1234567890abcdef0 \
  --groups sg-xxxxx sg-yyyyy
```

### Automatic Attachment (Launch Template)

To automatically attach this security group to all worker nodes, you would need to:

1. Create a launch template with the security group
2. Reference it in the node group configuration

**Note**: The current configuration creates the security group but doesn't automatically attach it to nodes. You'll need to manually attach it or modify the launch template.

## Usage with Kubernetes Services

### Example NodePort Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-nodeport-service
spec:
  type: NodePort
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 8080
      nodePort: 30080  # Must be in range 30000-32767
```

### Access the Service

```bash
# Get worker node public IP
kubectl get nodes -o wide

# Access the service
curl http://<NODE_PUBLIC_IP>:30080
```

## Validation

### Terraform Validation Results

✅ **Configuration Valid**: `terraform validate` passed
✅ **Plan Successful**: Security group will be created in VPC `vpc-0a1753e65db583cd6`
✅ **Port Range**: 30000-32767 (standard Kubernetes NodePort range)
✅ **Outputs Available**: `nodeport_security_group_id` and `nodeport_security_group_arn`

### Test the Security Group

After applying, test connectivity:

```bash
# Apply the configuration
terraform apply tfplan

# Get the security group ID
SG_ID=$(terraform output -raw nodeport_security_group_id)

# Verify the security group rules
aws ec2 describe-security-groups --group-ids $SG_ID
```

## Security Considerations

⚠️ **Production Warning**: The default configuration allows access from `0.0.0.0/0`. For production:

1. **Restrict CIDR blocks** to known IP ranges
2. **Use a Load Balancer** instead of NodePort for production services
3. **Enable VPC Flow Logs** to monitor traffic
4. **Consider using ClusterIP + Ingress** for better security

## Outputs

After applying, you'll have access to:

- `nodeport_security_group_id`: The security group ID for attaching to instances
- `nodeport_security_group_arn`: The ARN for IAM policies or cross-account access

## Next Steps

1. **Apply the configuration**: `terraform apply tfplan`
2. **Attach to worker nodes** (manual or via launch template)
3. **Deploy a NodePort service** to test
4. **Restrict CIDR blocks** for production use
5. **Monitor access logs** via VPC Flow Logs

## Troubleshooting

### Cannot access NodePort service

1. Verify security group is attached to worker nodes
2. Check that the NodePort is in range 30000-32767
3. Verify CIDR blocks allow your source IP
4. Ensure worker nodes have public IPs (if accessing from internet)
5. Check Network ACLs and route tables

### Security group not found

1. Ensure `terraform apply` completed successfully
2. Verify you're in the correct AWS region
3. Check VPC ID is correct in terraform.tfvars
