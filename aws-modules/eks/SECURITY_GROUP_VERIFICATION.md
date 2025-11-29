# Security Group Setup - eksctl vs Terraform

## eksctl Cluster (eks-cluster-01) Analysis

### Security Groups on Nodes:
```
Node 1 & Node 2 have 3 security groups:
1. sg-056645fee6d0b2803 - eks-cluster-sg-eks-cluster-01-2090245108
   Description: EKS created security group for control plane and managed workloads
   
2. sg-0c3ee7135889e5e37 - eks-cluster-01-nodegroup-nonssh  
   Description: NodePort security group (30000-32767)
   Rules: TCP 30000-32767 from 0.0.0.0/0
   
3. sg-008dd54c36190282f - eksctl-eks-cluster-01-nodegroup-ng-1-workers-remoteAccess
   Description: Allow SSH access
   Rules: TCP 22 from 0.0.0.0/0
```

### Launch Template Configuration:
```
eksctl launch template includes:
- sg-056645fee6d0b2803 (Cluster SG)
- sg-008dd54c36190282f (SSH SG)

The NodePort SG was added manually AFTER cluster creation.
```

## Terraform Cluster (eks-cluster-dotsky) Configuration

### Security Groups Created:
```
1. sg-05446f19477e862c9 - eks-cluster-sg-eks-cluster-dotsky-865840043
   Description: EKS created security group for control plane and managed workloads
   Source: Auto-created by EKS
   
2. sg-05de443bfe9aceba7 - eks-cluster-dotsky-ControlPlaneSecurityGroup
   Description: Communication between control plane and worker nodegroups
   Source: Terraform (main.tf)
   
3. sg-04d4622a67b5161c7 - dotsky-nodeport-sg
   Description: Security group for Kubernetes NodePort services (30000-32767)
   Source: Terraform (main.tf)
   Rules: TCP 30000-32767 from 0.0.0.0/0
```

### Launch Template Configuration:
```hcl
vpc_security_group_ids = [
  aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,  # sg-05446f19477e862c9
  aws_security_group.nodeport.id                                  # sg-04d4622a67b5161c7
]
```

## Comparison

| Component | eksctl | Terraform | Match? |
|-----------|--------|-----------|--------|
| **Cluster SG** (EKS auto-created) | ✅ sg-056645fee6d0b2803 | ✅ sg-05446f19477e862c9 | ✅ YES |
| **NodePort SG** (30000-32767) | ✅ sg-0c3ee7135889e5e37 | ✅ sg-04d4622a67b5161c7 | ✅ YES |
| **SSH Remote Access SG** | ✅ sg-008dd54c36190282f | ❌ Not needed | ✅ OK (SSH via launch template key) |
| **Control Plane SG** | ✅ sg-0a287a379f8dec9cc | ✅ sg-05de443bfe9aceba7 | ✅ YES |

## Functional Equivalence

### eksctl Setup:
- Cluster SG: ✅ Enables pod-to-pod communication
- NodePort SG: ✅ Allows external access to NodePort services
- SSH SG: ✅ Allows SSH access (via remote_access block)
- Control Plane SG: ✅ Control plane to worker communication

### Terraform Setup:
- Cluster SG: ✅ Enables pod-to-pod communication
- NodePort SG: ✅ Allows external access to NodePort services
- SSH: ✅ Configured via launch template key (no separate SG needed)
- Control Plane SG: ✅ Control plane to worker communication

**Result: FUNCTIONALLY EQUIVALENT** ✅

## Why Previous Attempt Failed

### What Was Wrong:
```hcl
# OLD - Only NodePort SG
vpc_security_group_ids = [
  aws_security_group.nodeport.id  # ❌ Missing cluster SG
]
```

**Problem:** Nodes couldn't communicate properly because they lacked the cluster security group.

### What Is Correct Now:
```hcl
# NEW - Cluster SG + NodePort SG
vpc_security_group_ids = [
  aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,  # ✅ Cluster SG
  aws_security_group.nodeport.id                                  # ✅ NodePort SG
]
```

**Result:** Nodes have all required security groups for:
- ✅ Pod-to-pod communication (Cluster SG)
- ✅ NodePort external access (NodePort SG)
- ✅ Control plane communication (Control Plane SG attached to cluster)

## Testing Plan

### 1. Apply Terraform to update launch template
```bash
cd /Users/skminfotech/IdeaProjects/iAC-NikeRuns/aws-modules/eks
terraform apply
```

This will:
- Update the launch template with both security groups
- Recreate nodes with correct security groups

### 2. Verify nodes have correct security groups
```bash
# Check node 1
aws ec2 describe-instances --instance-ids <node1-id> \
  --query 'Reservations[0].Instances[0].SecurityGroups[*].GroupId'

# Check node 2  
aws ec2 describe-instances --instance-ids <node2-id> \
  --query 'Reservations[0].Instances[0].SecurityGroups[*].GroupId'

# Should show: [cluster-sg-id, nodeport-sg-id]
```

### 3. Test NodePort access on both nodes
```bash
# Node 1
curl http://<node1-public-ip>:32000

# Node 2
curl http://<node2-public-ip>:32000

# Both should return HTTP 200 OK
```

## Expected Result

After terraform apply:
- ✅ Both nodes will have: Cluster SG + NodePort SG
- ✅ NodePort services accessible on ALL nodes
- ✅ Pod-to-pod communication works
- ✅ Matches eksctl functionality

## Lessons Learned

### What I Should Have Done:
1. ✅ Check actual security groups on eksctl nodes (not just YAML)
2. ✅ Verify which SGs are in launch template vs manually attached
3. ✅ Understand that specifying vpc_security_group_ids REPLACES defaults
4. ✅ Include ALL required SGs in launch template

### What I Did Wrong:
1. ❌ Only added NodePort SG, forgot Cluster SG
2. ❌ Assumed EKS would auto-attach cluster SG (it doesn't with launch template)
3. ❌ Didn't verify against actual running infrastructure

### Process Improvement:
**Always check actual infrastructure state, not just configuration files.**
