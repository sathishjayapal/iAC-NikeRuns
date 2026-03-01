# ADR-001: Terraform for Dual-Cloud Provisioning (Azure + AWS)

**Date:** 2026-02
**Status:** Accepted

## Context

Need to provision infrastructure on both Azure (sandbox) and AWS (production-like EKS + MSK). Options: Azure ARM templates + CloudFormation (cloud-native, separate), Pulumi, CDK, Terraform.

## Decision

Use **Terraform** with a modular structure — Azure modules under `/modules/`, AWS modules under `/aws-modules/`.

## Rationale

- **Cloud-agnostic HCL:** Single language and workflow for both cloud providers. `terraform plan` and `apply` work identically regardless of target cloud.
- **State management:** Terraform state tracks all provisioned resources, enabling accurate drift detection and safe incremental changes.
- **Mature provider ecosystem:** `azurerm` and `aws` providers cover every resource in this project. Both receive frequent updates.
- **Module reuse:** The module pattern (`modules/configserver`, `aws-modules/eks`) enables the same resource to be provisioned in multiple environments by varying `tfvars`.
- **Portfolio signal:** Demonstrating multi-cloud IaC with a single tool is a strong differentiator vs. cloud-specific tools.

## Trade-offs

- Terraform state file must be stored remotely (S3, Azure Blob) for team use. Currently using local state — acceptable for a solo project.
- `terraform destroy` is irreversible. Requires discipline in CI/CD pipelines.
- Terraform is not event-driven; it does not auto-remediate drift without a scheduled plan/apply cycle.

## Consequences

Each cloud target has its own root/module structure to keep `terraform init` and state isolated. Azure uses `main.tfvars`; AWS modules are currently applied independently per module directory.
