# MSK Module Architecture

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                           AWS Cloud                                  │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    VPC (192.168.0.0/16)                      │   │
│  │                                                               │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │   │
│  │  │  Subnet 1    │  │  Subnet 2    │  │  Subnet 3    │      │   │
│  │  │  (AZ-1)      │  │  (AZ-2)      │  │  (AZ-3)      │      │   │
│  │  │              │  │              │  │              │      │   │
│  │  │ ┌──────────┐ │  │ ┌──────────┐ │  │ ┌──────────┐ │      │   │
│  │  │ │ Broker 1 │ │  │ │ Broker 2 │ │  │ │ Broker 3 │ │      │   │
│  │  │ │ :9098    │ │  │ │ :9098    │ │  │ │ :9098    │ │      │   │
│  │  │ │ (IAM)    │ │  │ │ (IAM)    │ │  │ │ (IAM)    │ │      │   │
│  │  │ └──────────┘ │  │ └──────────┘ │  │ └──────────┘ │      │   │
│  │  │              │  │              │  │              │      │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │   │
│  │         │                  │                  │             │   │
│  │         └──────────────────┼──────────────────┘             │   │
│  │                            │                                │   │
│  │                    ┌───────▼────────┐                       │   │
│  │                    │  MSK Security  │                       │   │
│  │                    │     Group      │                       │   │
│  │                    │  - Port 9098   │                       │   │
│  │                    │  - Port 9094   │                       │   │
│  │                    │  - Port 2181   │                       │   │
│  │                    └────────────────┘                       │   │
│  │                            │                                │   │
│  │         ┌──────────────────┼──────────────────┐            │   │
│  │         │                  │                  │            │   │
│  │  ┌──────▼──────┐   ┌──────▼──────┐   ┌──────▼──────┐     │   │
│  │  │  Producer   │   │  Consumer   │   │   Admin     │     │   │
│  │  │  Instance   │   │  Instance   │   │  Instance   │     │   │
│  │  │  (EC2/ECS)  │   │  (EC2/ECS)  │   │  (EC2)      │     │   │
│  │  └─────────────┘   └─────────────┘   └─────────────┘     │   │
│  │         │                  │                  │            │   │
│  └─────────┼──────────────────┼──────────────────┼───────────┘   │
│            │                  │                  │                │
│     ┌──────▼──────┐    ┌──────▼──────┐   ┌──────▼──────┐        │
│     │  Producer   │    │  Consumer   │   │   Admin     │        │
│     │  IAM Role   │    │  IAM Role   │   │  IAM Role   │        │
│     │             │    │             │   │             │        │
│     │ • Create    │    │ • Read      │   │ • Full      │        │
│     │ • Write     │    │ • Describe  │   │   Access    │        │
│     │ Topics:     │    │ Topics:     │   │             │        │
│     │ myapp-*     │    │ myapp-*     │   │             │        │
│     └─────────────┘    └─────────────┘   └─────────────┘        │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                    CloudWatch Logs                          │  │
│  │  /aws/msk/cluster-name                                      │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                    CloudWatch Metrics                        │  │
│  │  - BytesInPerSec, BytesOutPerSec                            │  │
│  │  - MessagesInPerSec                                         │  │
│  │  - FetchConsumerTotalTimeMs                                 │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

## Component Breakdown

### 1. MSK Cluster
- **Brokers**: Distributed across multiple availability zones
- **Ports**: Only necessary ports opened based on configuration
- **Encryption**: TLS in transit, KMS at rest
- **Authentication**: IAM-based by default

### 2. Security Groups

#### MSK Security Group
```
Ingress Rules (conditional):
├── Port 9092 (Plaintext) - Only if encryption_in_transit = "PLAINTEXT"
├── Port 9094 (TLS) - Only if encryption_in_transit includes "TLS"
├── Port 9096 (SASL/SCRAM) - Only if enable_scram_auth = true
├── Port 9098 (IAM) - Only if enable_iam_auth = true
├── Port 2181 (Zookeeper) - Internal cluster only
├── Port 11001 (JMX) - Only if enable_jmx_exporter = true
└── Port 11002 (Node) - Only if enable_node_exporter = true

Egress Rules:
└── All traffic (required for cluster operations)
```

#### Client Security Group (Optional)
```
Ingress Rules:
└── Application-specific

Egress Rules:
└── To MSK Security Group (all ports)
```

### 3. IAM Roles and Policies

#### Producer Role
```
Permissions:
├── kafka-cluster:Connect
├── kafka-cluster:DescribeCluster
├── kafka-cluster:CreateTopic (with naming restriction)
├── kafka-cluster:DescribeTopic (with naming restriction)
├── kafka-cluster:WriteData (with naming restriction)
└── kafka-cluster:DescribeTopicDynamicConfiguration

Resource Restrictions:
└── Topics must match: ${topic_naming_prefix}*

Assume Role Policy:
├── EC2 instances
├── ECS tasks
├── Lambda functions
└── Custom ARNs
```

#### Consumer Role
```
Permissions:
├── kafka-cluster:Connect
├── kafka-cluster:DescribeCluster
├── kafka-cluster:DescribeTopic (with naming restriction)
├── kafka-cluster:ReadData (with naming restriction)
├── kafka-cluster:DescribeTopicDynamicConfiguration
├── kafka-cluster:DescribeGroup (with naming restriction)
└── kafka-cluster:AlterGroup (with naming restriction)

Resource Restrictions:
├── Topics must match: ${topic_naming_prefix}*
└── Groups must match: ${consumer_group_naming_prefix}*

Assume Role Policy:
├── EC2 instances
├── ECS tasks
├── Lambda functions
└── Custom ARNs
```

#### Admin Role
```
Permissions:
└── kafka-cluster:* (all actions)

Resources:
├── Cluster
├── All topics
└── All consumer groups

Assume Role Policy:
├── EC2 instances
└── Custom ARNs
```

## Data Flow

### Producer Flow
```
1. Application assumes Producer IAM Role
2. Application connects to MSK using IAM authentication
3. Application attempts to create topic "myapp-orders"
4. IAM policy validates topic name matches "myapp-*"
5. If valid, topic is created
6. Application writes messages to topic
7. IAM policy validates write permission
8. Messages are written to Kafka brokers
```

### Consumer Flow
```
1. Application assumes Consumer IAM Role
2. Application connects to MSK using IAM authentication
3. Application attempts to join consumer group "cg-myapp-processor"
4. IAM policy validates group name matches "cg-myapp-*"
5. If valid, consumer joins group
6. Application subscribes to topic "myapp-orders"
7. IAM policy validates topic name matches "myapp-*"
8. If valid, messages are consumed from topic
```

### Denied Flow
```
1. Application assumes Producer IAM Role
2. Application attempts to create topic "orders" (no prefix)
3. IAM policy checks topic name
4. Topic name doesn't match "myapp-*"
5. Access denied - Authorization error returned
6. Topic is not created
```

## Network Architecture

### Multi-AZ Deployment
```
Region: us-east-1
├── AZ-1 (us-east-1a)
│   ├── Subnet: 192.168.64.0/18
│   └── Broker 1
├── AZ-2 (us-east-1b)
│   ├── Subnet: 192.168.128.0/18
│   └── Broker 2
└── AZ-3 (us-east-1c)
    ├── Subnet: 192.168.192.0/18
    └── Broker 3
```

### Security Group Rules Flow
```
Client Application
       │
       │ (Assumes IAM Role)
       │
       ▼
Client Security Group (Optional)
       │
       │ (Egress: All to MSK SG)
       │
       ▼
MSK Security Group
       │
       │ (Ingress: Port 9098 from VPC CIDR)
       │
       ▼
MSK Broker Nodes
       │
       │ (Internal: Port 2181 between brokers)
       │
       ▼
Zookeeper (Internal)
```

## Topic Naming Enforcement

### IAM Policy Structure
```
Resource ARN Pattern:
arn:aws:kafka:{region}:{account}:topic/{cluster-name}/*/{prefix}*

Condition:
{
  "StringLike": {
    "kafka-cluster:topicName": "{prefix}*"
  }
}

Example:
Resource: arn:aws:kafka:us-east-1:123456789012:topic/my-cluster/*/myapp-*
Condition: topicName must start with "myapp-"

Valid Topics:
✓ myapp-orders
✓ myapp-payments
✓ myapp-users-events

Invalid Topics:
✗ orders
✗ payments
✗ other-app-orders
```

## Monitoring Architecture

### CloudWatch Integration
```
MSK Cluster
    │
    ├─► CloudWatch Logs
    │   └── /aws/msk/{cluster-name}
    │       ├── Broker logs
    │       ├── Controller logs
    │       └── State change logs
    │
    ├─► CloudWatch Metrics
    │   ├── BytesInPerSec
    │   ├── BytesOutPerSec
    │   ├── MessagesInPerSec
    │   ├── FetchConsumerTotalTimeMs
    │   └── ProduceTotalTimeMs
    │
    └─► Optional: S3 Logs
        └── s3://bucket/prefix/
            └── Archived broker logs
```

### Prometheus Integration (Optional)
```
MSK Cluster
    │
    ├─► JMX Exporter (Port 11001)
    │   └── Kafka JMX metrics
    │
    └─► Node Exporter (Port 11002)
        └── Node-level metrics

Prometheus Server
    │
    └─► Scrapes metrics from exporters
```

## Encryption Architecture

### Encryption in Transit
```
Client Application
    │
    │ (TLS 1.2+)
    │
    ▼
MSK Broker (Port 9094/9098)
    │
    │ (Optional: TLS between brokers)
    │
    ▼
Other MSK Brokers
```

### Encryption at Rest
```
MSK Broker
    │
    ▼
EBS Volume
    │
    │ (KMS Encryption)
    │
    ▼
AWS KMS Key
    │
    ├─► AWS Managed Key (default)
    └─► Customer Managed Key (optional)
```

## Deployment Flow

```
1. Terraform Init
   └── Download AWS provider

2. Terraform Plan
   ├── Validate VPC exists
   ├── Validate subnets exist
   ├── Calculate security group rules
   └── Generate IAM policies

3. Terraform Apply
   ├── Create Security Groups
   ├── Create IAM Roles
   ├── Create MSK Configuration
   ├── Create CloudWatch Log Group
   ├── Create MSK Cluster (15-20 min)
   └── Output connection details

4. Post-Deployment
   ├── Attach IAM roles to applications
   ├── Configure client applications
   ├── Create topics
   └── Start producing/consuming
```

## Scaling Architecture

### Horizontal Scaling
```
Initial: 3 brokers (1 per AZ)
    │
    ▼
Scale Up: 6 brokers (2 per AZ)
    │
    ▼
Scale Up: 9 brokers (3 per AZ)
```

### Vertical Scaling
```
kafka.m5.large (2 vCPU, 8 GB)
    │
    ▼
kafka.m5.xlarge (4 vCPU, 16 GB)
    │
    ▼
kafka.m5.2xlarge (8 vCPU, 32 GB)
```

### Storage Scaling
```
100 GB per broker
    │
    ▼
500 GB per broker
    │
    ▼
1000 GB per broker
```

## Disaster Recovery

### Multi-AZ Deployment
- Brokers distributed across 3 availability zones
- Automatic failover if AZ becomes unavailable
- Replication factor of 3 ensures data durability

### Backup Strategy
```
MSK Cluster
    │
    ├─► CloudWatch Logs (7-30 days retention)
    │
    ├─► S3 Logs (Long-term archive)
    │
    └─► Topic Data
        └── Replicated across 3 brokers
            └── Min in-sync replicas: 2
```

## Summary

This architecture provides:
- ✅ High availability across multiple AZs
- ✅ Security through IAM and encryption
- ✅ Network isolation via security groups
- ✅ Topic naming enforcement via IAM policies
- ✅ Comprehensive monitoring and logging
- ✅ Scalability in multiple dimensions
- ✅ Disaster recovery through replication
