# Using Environment Variables with Terraform

## Overview

Terraform can read variables from environment variables instead of `terraform.tfvars` files. This is useful for:
- CI/CD pipelines
- Keeping sensitive values out of version control
- Different environments (dev, staging, prod)

## How Terraform Reads Environment Variables

Terraform automatically reads environment variables with the prefix `TF_VAR_`.

**Format:** `TF_VAR_<variable_name>`

Example:
```bash
export TF_VAR_region="us-east-1"
export TF_VAR_cluster_name="eks-cluster-dotsky"
```

## Usage

### Option 1: Source the script (Recommended)

```bash
# Make the script executable
chmod +x set-env-vars.sh

# Source it to set variables in your current shell
source set-env-vars.sh

# Or use the dot notation
. set-env-vars.sh

# Now run terraform
terraform plan
terraform apply
```

### Option 2: Run in the same command

```bash
# Export variables and run terraform in one line
source set-env-vars.sh && terraform apply
```

### Option 3: Set variables inline

```bash
TF_VAR_region="us-east-1" \
TF_VAR_cluster_name="eks-cluster-dotsky" \
terraform plan
```

## Variable Types

### Simple String Variables
```bash
export TF_VAR_region="us-east-1"
export TF_VAR_cluster_name="eks-cluster-dotsky"
```

### Number Variables
```bash
export TF_VAR_node_desired_capacity="2"
export TF_VAR_node_min_size="1"
```

### Boolean Variables
```bash
export TF_VAR_enable_oidc="true"
```

### Map Variables (JSON format)
```bash
# Simple map
export TF_VAR_node_labels='{"role":"workers"}'

# Complex map
export TF_VAR_common_tags='{"Environment":"development","ManagedBy":"terraform"}'
```

### List Variables (JSON format)
```bash
export TF_VAR_subnet_ids='["subnet-123","subnet-456","subnet-789"]'
```

## Verify Variables Are Set

```bash
# Check all TF_VAR variables
env | grep TF_VAR_

# Check specific variable
echo $TF_VAR_region
echo $TF_VAR_cluster_name
```

## Unset Variables

```bash
# Unset all TF_VAR variables
unset $(env | grep TF_VAR_ | cut -d= -f1)

# Unset specific variable
unset TF_VAR_region
```

## Priority Order

Terraform reads variables in this order (later overrides earlier):

1. Environment variables (`TF_VAR_*`)
2. `terraform.tfvars` file
3. `terraform.tfvars.json` file
4. `*.auto.tfvars` files (alphabetical order)
5. `-var` and `-var-file` command line flags

## Using Both tfvars and Environment Variables

You can use both! Environment variables will override tfvars values.

```bash
# Set some variables via environment
export TF_VAR_cluster_name="eks-cluster-prod"

# terraform.tfvars has cluster_name = "eks-cluster-dotsky"
# But environment variable takes precedence

terraform plan
# Will use cluster_name = "eks-cluster-prod"
```

## CI/CD Integration

### GitHub Actions Example
```yaml
- name: Terraform Apply
  env:
    TF_VAR_region: ${{ secrets.AWS_REGION }}
    TF_VAR_cluster_name: ${{ secrets.CLUSTER_NAME }}
    TF_VAR_service_role_arn: ${{ secrets.SERVICE_ROLE_ARN }}
  run: terraform apply -auto-approve
```

### GitLab CI Example
```yaml
terraform_apply:
  script:
    - export TF_VAR_region=$AWS_REGION
    - export TF_VAR_cluster_name=$CLUSTER_NAME
    - terraform apply -auto-approve
```

### Jenkins Example
```groovy
withEnv([
  "TF_VAR_region=us-east-1",
  "TF_VAR_cluster_name=eks-cluster-dotsky"
]) {
  sh 'terraform apply -auto-approve'
}
```

## Best Practices

### 1. Keep Sensitive Values in Environment Variables
```bash
# Don't commit to git
export TF_VAR_service_role_arn="arn:aws:iam::123456789:role/sensitive-role"
export TF_VAR_ssh_key_name="my-private-key"
```

### 2. Use .env Files (with gitignore)
Create `.env` file:
```bash
# .env
export TF_VAR_region="us-east-1"
export TF_VAR_cluster_name="eks-cluster-dotsky"
# ... more variables
```

Add to `.gitignore`:
```
.env
*.env
```

Load it:
```bash
source .env
terraform apply
```

### 3. Different Environments
```bash
# dev.env
export TF_VAR_cluster_name="eks-cluster-dev"
export TF_VAR_node_instance_type="t2.micro"

# prod.env
export TF_VAR_cluster_name="eks-cluster-prod"
export TF_VAR_node_instance_type="t3.large"
```

Usage:
```bash
source dev.env && terraform apply
# or
source prod.env && terraform apply
```

## Troubleshooting

### Variables Not Being Read
```bash
# Check if variables are set
env | grep TF_VAR_

# Check terraform is reading them
terraform console
> var.region
"us-east-1"
```

### Map Variables Not Working
Make sure to use proper JSON format:
```bash
# ❌ Wrong
export TF_VAR_tags='{Environment: development}'

# ✅ Correct
export TF_VAR_tags='{"Environment":"development"}'
```

### Variables Disappearing
Environment variables only last for the current shell session. Use:
```bash
# Add to ~/.bashrc or ~/.zshrc for persistence
echo 'export TF_VAR_region="us-east-1"' >> ~/.bashrc
source ~/.bashrc
```

## Complete Example

```bash
# 1. Set variables
source set-env-vars.sh

# 2. Verify
env | grep TF_VAR_

# 3. Run terraform (no need for terraform.tfvars)
terraform init
terraform plan
terraform apply

# 4. Clean up
unset $(env | grep TF_VAR_ | cut -d= -f1)
```

## Comparison: tfvars vs Environment Variables

| Aspect | terraform.tfvars | Environment Variables |
|--------|------------------|----------------------|
| **Ease of use** | ✅ Simple, one file | ⚠️ Need to export each |
| **Version control** | ✅ Easy to track | ❌ Not in git |
| **CI/CD** | ⚠️ Need to manage files | ✅ Native support |
| **Secrets** | ❌ Risk of committing | ✅ Keep out of git |
| **Multiple envs** | ⚠️ Need multiple files | ✅ Easy switching |
| **Override** | ⚠️ Need to edit file | ✅ Just export |

## Recommendation

**Use both:**
- `terraform.tfvars` for non-sensitive, common values
- Environment variables for sensitive values and CI/CD

Example:
```bash
# terraform.tfvars (committed to git)
region = "us-east-1"
vpc_id = "vpc-0a1753e65db583cd6"

# Environment variables (not in git)
export TF_VAR_service_role_arn="arn:aws:iam::..."
export TF_VAR_ssh_key_name="my-private-key"
```
