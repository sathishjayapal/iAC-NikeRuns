# Pre-Deployment Validation Checklist

## What I Should Have Done BEFORE You Ran Terraform

### 1. Check Existing eksctl Cluster Behavior
```bash
# Check what addons eksctl actually created successfully
aws eks list-addons --cluster-name eks-cluster-01 --region us-east-1

# Check status of each addon
for addon in vpc-cni kube-proxy coredns metrics-server; do
  aws eks describe-addon --cluster-name eks-cluster-01 --addon-name $addon --region us-east-1 --query 'addon.status'
done
```

**Result I found AFTER you had issues:**
- vpc-cni: ACTIVE ✅
- kube-proxy: ACTIVE ✅
- coredns: ACTIVE (but took long) ⚠️
- metrics-server: CREATE_FAILED ❌

**I should have checked this FIRST and only included working addons.**

---

### 2. Verify Launch Template Requirements
```bash
# Check if eksctl uses launch template
aws eks describe-nodegroup --cluster-name eks-cluster-01 --nodegroup-name ng-1-workers --region us-east-1 --query 'nodegroup.launchTemplate'
```

**I should have verified:**
- Does launch template require disk config? YES
- Does remote_access conflict with launch template? YES
- What security groups does launch template need? NodePort SG

---

### 3. Test Addon Creation Time
```bash
# Check how long addons took to create in eksctl cluster
aws eks describe-addon --cluster-name eks-cluster-01 --addon-name coredns --region us-east-1 --query 'addon.createdAt'
```

**I should have known:**
- coredns can get stuck in CREATING (AWS bug)
- metrics-server fails frequently
- Default 20min timeout is not enough

---

### 4. Compare Security Groups
```bash
# Check eksctl cluster security groups
aws eks describe-cluster --cluster-name eks-cluster-01 --region us-east-1 --query 'cluster.resourcesVpcConfig.securityGroupIds'

# Check node group security groups
aws eks describe-nodegroup --cluster-name eks-cluster-01 --nodegroup-name ng-1-workers --region us-east-1 --query 'nodegroup.resources.remoteAccessSecurityGroup'
```

**I should have verified:**
- Does eksctl create remote access SG? NO
- How many security groups total? 2 (control plane + cluster)

---

## Better Process Going Forward

### Phase 1: Research & Validate (BEFORE giving you code)
1. ✅ Check eksctl cluster for actual behavior
2. ✅ Identify what works vs what fails
3. ✅ Test addon creation times
4. ✅ Verify security group setup
5. ✅ Check for known AWS bugs

### Phase 2: Create Terraform Code
1. ✅ Only include components that work in eksctl
2. ✅ Add appropriate timeouts based on actual times
3. ✅ Handle known AWS bugs upfront
4. ✅ Match security group setup exactly

### Phase 3: Validation Before You Run
1. ✅ Run `terraform plan` and review
2. ✅ Check for potential conflicts (launch template + remote_access)
3. ✅ Verify resource dependencies
4. ✅ Estimate deployment time

### Phase 4: Provide Code with Warnings
```markdown
## Known Issues to Expect:
- ⚠️ coredns addon may get stuck (AWS bug) - not managed as addon
- ⚠️ metrics-server fails in eksctl too - not included
- ⚠️ Deployment takes ~10-15 minutes
- ⚠️ Launch template requires disk config
```

---

## What I Did Wrong This Time

### Issue 1: metrics-server timeout
**What I did:** Included it because cluster.yaml mentions it
**What I should have done:** Check eksctl cluster first, see it FAILED, exclude it

### Issue 2: remote_access + launch_template conflict
**What I did:** Added both without testing
**What I should have done:** Research AWS docs, know they're mutually exclusive

### Issue 3: disk_size in wrong place
**What I did:** Put it in node group
**What I should have done:** Know launch template requires it in block_device_mappings

### Issue 4: coredns stuck in CREATING
**What I did:** Included as addon
**What I should have done:** Test addon creation, discover AWS bug, exclude it

### Issue 5: Extra SSH security group
**What I did:** Used remote_access block
**What I should have done:** Check eksctl cluster, see it doesn't create this SG

---

## Improved Workflow Template

When you ask me to create Terraform matching eksctl:

### Step 1: Analyze Existing (5 min)
```bash
# I should run these commands FIRST
aws eks describe-cluster --name <eksctl-cluster>
aws eks list-addons --cluster-name <eksctl-cluster>
aws eks describe-nodegroup --cluster-name <eksctl-cluster> --nodegroup-name <ng>
# Check addon statuses, security groups, launch template config
```

### Step 2: Document Findings (2 min)
```markdown
## Findings from eksctl cluster:
- Addons working: vpc-cni, kube-proxy
- Addons failed: metrics-server
- Addons stuck: coredns (AWS bug)
- Security groups: 2 (no remote access SG)
- Launch template: Yes, with disk config
```

### Step 3: Create Terraform (10 min)
- Only include working components
- Add workarounds for known bugs
- Match exact configuration

### Step 4: Pre-validate (3 min)
```bash
# Dry run checks
terraform validate
terraform plan
# Review for conflicts
```

### Step 5: Provide with Context (2 min)
```markdown
## Code ready with:
✅ Only working addons included
✅ Known bugs handled
✅ Estimated time: 10-15 min
⚠️ Excluded: metrics-server (fails in eksctl too)
⚠️ Excluded: coredns addon (AWS bug, runs automatically)
```

---

## How You Can Help Me Do Better

### When asking for Terraform code:
1. ✅ Point me to existing working cluster (like you did)
2. ✅ Tell me if time is critical
3. ✅ Let me know if you want me to validate first

### I will:
1. ✅ Check existing cluster behavior FIRST
2. ✅ Document findings BEFORE coding
3. ✅ Warn about known issues UPFRONT
4. ✅ Provide realistic time estimates
5. ✅ Test configurations before you run them

---

## Summary

**What I should have done:**
1. Check eks-cluster-01 addons → See metrics-server FAILED
2. Test coredns creation → See it gets stuck
3. Check security groups → See no remote access SG
4. Research launch template → Know disk config required
5. **THEN** give you optimized code that works first time

**Instead I:**
1. Converted cluster.yaml literally
2. Let you hit errors
3. Fixed reactively

**Going forward:**
- I'll validate against existing infrastructure FIRST
- I'll document known issues UPFRONT
- I'll provide realistic expectations
- You'll run code that works the first time
