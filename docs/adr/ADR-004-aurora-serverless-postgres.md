# ADR-004: Aurora PostgreSQL Serverless v2 for Application Database

**Date:** 2026-02
**Status:** Accepted

## Context

The runs-app service needs a managed PostgreSQL database on AWS. Options: RDS PostgreSQL (provisioned), Aurora PostgreSQL (provisioned), Aurora Serverless v2, ElastiCache + DynamoDB, self-managed PostgreSQL on EC2.

## Decision

Use **Aurora PostgreSQL Serverless v2** (0.5–2.0 ACU, db.serverless instance class).

## Rationale

- **Cost efficiency:** Serverless v2 scales down to 0.5 ACU (~$0.06/hr) during low traffic and up to 2.0 ACU under load. For a sandbox/portfolio workload with variable traffic, this is dramatically cheaper than a provisioned db.t3.micro running 24/7.
- **No capacity planning:** ACU range (0.5–2.0) handles typical Spring Boot application load without manual instance sizing.
- **Aurora advantages:** Automated failover, 6-way replication across 3 AZs, and up to 5x read throughput vs. standard RDS — at no extra configuration cost.
- **Secrets Manager integration:** DB credentials are stored in Secrets Manager (JSON format) and accessed by pods via IRSA — no credentials in environment variables or config maps.
- **Budget Lambda safeguard:** A Lambda function triggers on budget threshold breach and can either stop the Aurora cluster or revoke inbound security group rules — prevents runaway cost in dev environments.

## Trade-offs

- Serverless v2 has a minimum of 0.5 ACU — cannot scale to zero (unlike Serverless v1). Idle cost exists.
- Aurora is not available in all regions. us-east-1 is fully supported.
- Secrets Manager recovery window is set to 0 days (immediate deletion) — acceptable for dev but dangerous in production (should be 7–30 days).

## Consequences

Database name: `runsappdb`. Port: 5432. The Spring Boot application uses `spring.datasource.url` from the Secrets Manager secret injected as an environment variable. Flyway runs migrations on startup via the `runs-app` module. KMS encryption at-rest uses AWS-managed keys.
