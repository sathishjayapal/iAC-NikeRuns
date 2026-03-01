# ADR-003: AWS MSK for Managed Kafka

**Date:** 2026-02
**Status:** Accepted

## Context

The fitness data streaming pipeline (Strava, Garmin) requires Kafka. Options: self-managed Kafka on EC2, Confluent Cloud, AWS MSK, Azure Event Hubs (Kafka protocol).

## Decision

Use **AWS MSK** with 3 brokers (kafka.m5.large), Kafka 3.5.1, and IAM authentication.

## Rationale

- **No operational overhead:** MSK manages broker JVM tuning, OS patching, ZooKeeper/KRaft, and replication. Zero Kafka administration required.
- **IAM authentication:** Removes the need for SASL/SCRAM user management. IAM roles (producer/consumer/admin) are provisioned in Terraform and assumed via IRSA — consistent with the EKS security model.
- **Topic naming enforcement via IAM:** IAM policies enforce `app-*` topic prefix and `cg-*` consumer group prefix. This prevents naming chaos across teams/services without a separate Schema Registry ACL layer.
- **TLS in-transit + KMS at-rest:** Both encryption layers are enabled by default — no additional configuration needed for compliance.
- **CloudWatch integration:** Broker logs → `/aws/msk/cluster-name` (7-day retention) without log agent configuration.
- **Min ISR = 2, replication = 3:** Data is durable as long as 2 of 3 brokers are alive. Tolerates a single broker failure without data loss.

## Trade-offs

- `kafka.m5.large` is expensive (~$0.21/hr per broker × 3 = ~$450/month). Appropriate for production; use `kafka.t3.small` for development cost savings.
- Public access is disabled — consumers must be in the same VPC or use VPC peering/Transit Gateway.
- Auto-create topics is disabled — topics must be pre-created (good discipline; prevents accidental topic proliferation).

## Consequences

All Kafka producer/consumer services in EKS use IAM auth via IRSA. Three IAM roles are created: `kafka-producer-role`, `kafka-consumer-role`, `kafka-admin-role`. Services pick up the appropriate role based on their Kubernetes service account annotation.
