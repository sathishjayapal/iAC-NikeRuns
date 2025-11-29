# eksctl vs Terraform Comparison

## What Now Matches ✅

### 1. **EKS Addons** ✅
Both eksctl and Terraform now install:
- `vpc-cni` - Pod networking
- `kube-proxy` - Network proxy  
- `coredns` - DNS resolution
- `metrics-server` - Resource metrics

### 2. **IAM Policies** ✅
Node group IAM role has the same 3 policies:
- `AmazonEKSWorkerNodePolicy`
- `AmazonEKS_CNI_Policy`
- `AmazonEC2ContainerRegistryReadOnly`

### 3. **OIDC Provider** ✅
Both create OIDC provider for IRSA (IAM Roles for Service Accounts)

### 4. **Node Configuration** ✅
- Instance type: `t2.micro`
- Desired capacity: 2
- Min size: 1
- Max size: 4
- SSH enabled with key: `foreksworkloads`
- Labels: `role: workers`
- Disk size: 80GB

### 5. **Cluster Configuration** ✅
- Region: `us-east-1`
- VPC and subnets: Same IDs
- Service role ARN: Same
- Public endpoint: enabled
- Private endpoint: disabled

### 6. **Security Groups** ✅
Both create:
- **Control Plane Security Group** - For control plane and worker communication
  - Egress: Allow all outbound traffic
- **Cluster Security Group** - Auto-created by EKS for ENIs
- **No remote access security group** - SSH is handled via launch template, not remote_access block

### 7. **SSH Access** ✅
Both use launch template with SSH key:
- Key name configured in launch template
- No separate remote access security group created
- IMDSv2 required (http_tokens = "required")

## Differences That Still Exist ⚠️

### 1. **Disk Type and Performance**
**eksctl sets:**
```yaml
volumeType: gp3
volumeSize: 80
volumeIOPS: 3000
volumeThroughput: 125
```

**Terraform sets:**
```hcl
disk_size = 80
# Uses default: gp3 with default IOPS/throughput
```

**Impact:** Terraform uses AWS defaults for gp3 which are the same values

### 2. **Additional Labels/Tags**
**eksctl adds:**
```yaml
alpha.eksctl.io/cluster-name: eks-cluster-01
alpha.eksctl.io/nodegroup-name: ng-1-workers
alpha.eksctl.io/nodegroup-type: managed
```

**Terraform:**
- Only adds user-specified tags
- Does not add eksctl-specific labels

**Impact:** None - these are just metadata tags

### 3. **IMDS Configuration**
**eksctl sets:**
```yaml
disableIMDSv1: true
disablePodIMDS: false
```

**Terraform:**
- Uses AWS defaults (IMDSv2 preferred but v1 not disabled)

**Impact:** Minor security difference - eksctl is more secure by default

### 4. **VPC Resource Controller Policy**
**eksctl enables:**
```yaml
vpcResourceControllerPolicy: true
```

**Terraform:**
- Not explicitly set
- Depends on the service role you're using

**Impact:** If your service role `sathisheksclusterservicerole` already has this policy, no difference

## Summary

The Terraform code now **functionally matches** what eksctl creates:
- ✅ Same addons installed
- ✅ Same IAM policies
- ✅ Same node configuration
- ✅ Same OIDC setup

**Minor differences** are mostly metadata and default AWS settings that don't affect functionality.

## Verification Commands

After running Terraform, verify it matches eksctl:

```bash
# Check addons
aws eks list-addons --cluster-name eks-cluster-dotsky --region us-east-1

# Check node group
aws eks describe-nodegroup --cluster-name eks-cluster-dotsky --nodegroup-name ng-dotskyclstr-workers --region us-east-1

# Check OIDC provider
aws eks describe-cluster --name eks-cluster-dotsky --region us-east-1 --query 'cluster.identity.oidc'
```
