# ADR-002: AWS EKS for Container Orchestration

**Date:** 2026-02
**Status:** Accepted

## Context

The NikeRuns microservice ecosystem (accounts, cards, loans, trackgarmin, trackstrava, etc.) needs an orchestration platform. Options: ECS Fargate, EKS, self-managed Kubernetes on EC2, Azure AKS.

## Decision

Use **Amazon EKS** (Kubernetes 1.28) with a managed node group.

## Rationale

- **Managed control plane:** EKS manages the API server, etcd, and controller manager. Only worker nodes (t3.micro) are our responsibility.
- **IRSA (IAM Roles for Service Accounts):** OIDC provider enables pods to assume IAM roles without embedding credentials. MSK IAM auth and Secrets Manager access both rely on this.
- **AWS Load Balancer Controller:** Helm-deployed LBC provisions ALBs from Kubernetes `Ingress` resources — no manual load balancer management.
- **Ecosystem:** EKS integrates natively with MSK (Kafka), Aurora PostgreSQL, CloudWatch, and Secrets Manager — all used in this project.
- **Transferable skills:** Kubernetes knowledge is cloud-portable; configuration developed here works on GKE or AKS with minor changes.

## Trade-offs

- t3.micro nodes are underpowered for production Spring Boot workloads (1 vCPU, 1 GB RAM). Appropriate for sandbox/demo; production would use t3.medium or larger.
- EKS startup takes 10–15 minutes for a fresh cluster. Not suitable for rapid iteration on infra changes.
- CoreDNS is NOT installed as an EKS managed addon (known account bug) — runs natively instead.
- Metrics Server installation was skipped (fails in this account) — horizontal pod autoscaling is unavailable.

## Consequences

Node group scales from 1 to 4 nodes (desired: 2). NodePort security group (30000-32767) is open to 0.0.0.0/0 — acceptable for demo; tighten for production. EBS volumes are gp3 (80 GB, 3000 IOPS, 125 MB/s) per node for adequate I/O headroom.
