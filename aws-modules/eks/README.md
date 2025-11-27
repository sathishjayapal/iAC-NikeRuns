# EKS Cluster Terraform Configuration

This Terraform configuration creates an AWS EKS cluster based on the eksctl `cluster.yaml` specification.

## Features

- **EKS Cluster**: Kubernetes cluster with configurable version
- **Managed Node Group**: Auto-scaling worker nodes with t2.micro instances
- **OIDC Provider**: Enables IAM Roles for Service Accounts (IRSA)
- **SSH Access**: Configurable SSH access to worker nodes
- **Cluster Autoscaler Tags**: Pre-configured tags for cluster autoscaler

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.3.0
3. Existing VPC and subnets (or use the vpc module)
4. IAM role for EKS cluster service
5. EC2 key pair for SSH access

## Configuration

### Update terraform.tfvars

Replace the placeholder values with your actual AWS resource IDs:

```hcl
vpc_id       = "vpc-xxxxxxxxx"        # Your VPC ID
subnet_id_a  = "subnet-xxxxxxxxx"     # Subnet in AZ a
subnet_id_b  = "subnet-xxxxxxxxx"     # Subnet in AZ b
subnet_id_c  = "subnet-xxxxxxxxx"     # Subnet in AZ c
service_role_arn = "arn:aws:iam::ACCOUNT_ID:role/EKSClusterServiceRole"
ssh_key_name = "your-key-pair-name"
```

## Usage

### Initialize Terraform

```bash
cd eks
terraform init
```

### Plan the deployment

```bash
terraform plan
```

### Apply the configuration

```bash
terraform apply
```

### Configure kubectl

After the cluster is created, configure kubectl to access it:

```bash
aws eks update-kubeconfig --region ap-southeast-1 --name eks-cluster-01
```

### Verify the cluster

```bash
kubectl get nodes
kubectl get pods -A
```

## Cluster Autoscaler

The node group is pre-configured with tags for the Kubernetes Cluster Autoscaler:

- `k8s.io/cluster-autoscaler/enabled: "true"`
- `k8s.io/cluster-autoscaler/eks-cluster-01: "owned"`

To deploy the cluster autoscaler, follow the [AWS documentation](https://docs.aws.amazon.com/eks/latest/userguide/autoscaling.html).

## Node Configuration

- **Instance Type**: t2.micro
- **Desired Capacity**: 2 nodes
- **Min Size**: 1 node
- **Max Size**: 4 nodes
- **Max Pods Per Node**: 100 (configurable via launch template)

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Mapping from cluster.yaml

| eksctl (cluster.yaml) | Terraform Resource |
|----------------------|-------------------|
| `metadata.name` | `aws_eks_cluster.this.name` |
| `metadata.region` | `var.region` |
| `vpc.id` | `var.vpc_id` |
| `vpc.subnets.public` | `var.subnet_id_*` |
| `managedNodeGroups` | `aws_eks_node_group.workers` |
| `iam.withOIDC` | `aws_iam_openid_connect_provider.cluster` |
| `iam.serviceRoleARN` | `var.service_role_arn` |

## Notes

- The `maxPodsPerNode: 100` setting requires a custom launch template with user data script
- If you don't need custom max pods, set `max_pods_per_node = null` in variables
- The cluster role can be created by Terraform (set `create_cluster_role = true`) or use an existing role
