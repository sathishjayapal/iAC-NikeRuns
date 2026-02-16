# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Dual-cloud Terraform IaC project provisioning infrastructure for the Nike Runs application ecosystem:
- **Azure**: Config server (ACI), PostgreSQL, blob storage, Log Analytics, Service Bus, Event Grid
- **AWS**: EKS Kubernetes cluster, MSK Kafka, EC2 instances, VPC networking

## Project Structure

- `root.tf` / `root-variables.tf` / `main.tfvars` — Azure root configuration (calls 6 modules)
- `modules/` — Azure modules: `configserver`, `PostgreSQL`, `storage`, `logs`, `service-bus`, `eventgrid`, `resource-groups`
- `aws-modules/` — AWS infrastructure:
  - `main.tf` + `awsroot.tf` — EC2 instance and AWS provider
  - `vpc/` — VPC with 3 public subnets (192.168.0.0/16)
  - `eks/` — EKS cluster with managed node groups, OIDC/IRSA, AWS LB Controller (Helm)
  - `kafka/` — MSK cluster with IAM auth, security groups, producer/consumer/admin IAM roles
  - `scripts/user_data.sh` — EC2 bootstrap script

## Common Commands

### Azure Modules (run from repo root)

```bash
terraform init
terraform plan -var-file="main.tfvars"
terraform apply -var-file="main.tfvars"
terraform destroy -var-file="main.tfvars"
```

### AWS EKS Module (run from aws-modules/eks/)

```bash
terraform init
terraform plan
terraform apply
```

EKS uses a separate `terraform.tfvars` (gitignored) for sensitive values. Set environment variables or create the tfvars file before running.

### AWS Kafka Module (run from aws-modules/kafka/)

```bash
terraform init
terraform plan
terraform apply
```

## Architecture Notes

### Module Pattern
Each module has `main.tf` (resources) and `variables.tf` (inputs), with optional `output.tf`. Variables flow: `main.tfvars` → `root-variables.tf` → module `variables.tf`. When adding a new variable, it must be defined at all three levels.

### Azure Sandbox
The Azure environment uses A Cloud Guru sandbox subscriptions. The `.terraform/` folder and `.terraform.lock.hcl` must be deleted when the sandbox resets since provider auth changes.

### AWS EKS
- Cluster: `sathish-eks-cluster-01`, Kubernetes 1.28, region `us-east-1`
- Node group: `t3.micro` instances (min=1, max=4, desired=2) with 80GB gp3 volumes
- CoreDNS is NOT managed as an EKS addon due to an AWS bug (see `aws-modules/eks/COREDNS_ADDON_BUG.md`)
- IRSA (IAM Roles for Service Accounts) enabled via OIDC provider
- AWS Load Balancer Controller deployed via Helm provider (v1.6.2)
- Subnets tagged with `kubernetes.io/role/elb` for ELB discovery

### AWS MSK (Kafka)
- Default Kafka version 3.5.1 with IAM authentication
- Security groups enforce minimal port exposure based on enabled auth methods
- IAM roles enforce topic naming prefix conventions for producer/consumer isolation

### State Management
Local state files are used (no remote backend). State files and lock files are gitignored. The EKS module has its own `.terraform/` directory with downloaded providers (aws v5.100.0, tls v4.1.0, kubernetes, helm).

### EC2
- Amazon Linux 2023 (`al2023-ami`), `t3.micro`
- Security group allows inbound 80 (HTTP), 8888 (app), 22 (SSH)
- Key pair `formypc` required — create with: `aws ec2 create-key-pair --key-name formypc --query 'KeyMaterial' --output text > formypc.pem`