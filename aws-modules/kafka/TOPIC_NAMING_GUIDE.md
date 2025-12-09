# Kafka Topic Naming Convention Enforcement Guide

This guide explains how the MSK module enforces topic naming conventions using IAM policies.

## Overview

The module uses AWS IAM policies to enforce topic naming conventions at the infrastructure level. This ensures that:
- All topics follow a consistent naming pattern
- Unauthorized topics cannot be created
- Different applications can be isolated by topic prefixes
- Consumer groups follow naming standards

## How It Works

### 1. IAM-Based Access Control

The module creates three types of IAM roles:

#### Producer Role
- **Purpose**: For applications that write data to Kafka
- **Permissions**: 
  - Create topics matching `${topic_naming_prefix}*`
  - Write data to topics matching `${topic_naming_prefix}*`
  - Describe topics and cluster
- **Restriction**: Cannot create or write to topics that don't match the prefix

#### Consumer Role
- **Purpose**: For applications that read data from Kafka
- **Permissions**:
  - Read data from topics matching `${topic_naming_prefix}*`
  - Join consumer groups matching `${consumer_group_naming_prefix}*`
  - Describe topics, groups, and cluster
- **Restriction**: Cannot read from topics or join groups that don't match the prefixes

#### Admin Role
- **Purpose**: For cluster administrators
- **Permissions**: Full access to all cluster operations
- **Use Case**: Manual administration, topic management, monitoring

### 2. IAM Policy Structure

The IAM policies use resource-based restrictions with conditions:

```json
{
  "Effect": "Allow",
  "Action": ["kafka-cluster:CreateTopic", "kafka-cluster:WriteData"],
  "Resource": "arn:aws:kafka:region:account:topic/cluster-name/*/${topic_naming_prefix}*",
  "Condition": {
    "StringLike": {
      "kafka-cluster:topicName": "${topic_naming_prefix}*"
    }
  }
}
```

This ensures that even if someone tries to bypass the resource ARN, the condition will still enforce the naming convention.

## Configuration

### Setting Up Naming Conventions

```hcl
module "msk" {
  source = "./aws-modules/kafka"

  # ... other configuration ...

  # Define your naming conventions
  topic_naming_prefix          = "myapp-"
  consumer_group_naming_prefix = "cg-myapp-"
}
```

### Naming Convention Examples

#### Environment-Based Prefixes
```hcl
# Development
topic_naming_prefix = "dev-"
# Topics: dev-orders, dev-payments, dev-users

# Staging
topic_naming_prefix = "staging-"
# Topics: staging-orders, staging-payments, staging-users

# Production
topic_naming_prefix = "prod-"
# Topics: prod-orders, prod-payments, prod-users
```

#### Application-Based Prefixes
```hcl
# E-commerce application
topic_naming_prefix = "ecommerce-"
# Topics: ecommerce-orders, ecommerce-inventory, ecommerce-shipping

# Analytics application
topic_naming_prefix = "analytics-"
# Topics: analytics-events, analytics-metrics, analytics-logs
```

#### Hierarchical Prefixes
```hcl
# Combine environment and application
topic_naming_prefix = "prod-ecommerce-"
# Topics: prod-ecommerce-orders, prod-ecommerce-payments

consumer_group_naming_prefix = "cg-prod-ecommerce-"
# Groups: cg-prod-ecommerce-processor, cg-prod-ecommerce-analytics
```

## Using the IAM Roles

### For Applications Running on EC2

```bash
# Attach the producer role to your EC2 instance profile
aws ec2 associate-iam-instance-profile \
  --instance-id i-1234567890abcdef0 \
  --iam-instance-profile Name=kafka-producer-instance-profile
```

### For Applications Running on ECS

```hcl
resource "aws_ecs_task_definition" "app" {
  family                   = "my-app"
  task_role_arn           = module.msk.producer_role_arn
  execution_role_arn      = aws_iam_role.ecs_execution_role.arn
  
  # ... container definitions ...
}
```

### For Lambda Functions

```hcl
resource "aws_lambda_function" "producer" {
  function_name = "kafka-producer"
  role          = module.msk.producer_role_arn
  
  # ... other configuration ...
}
```

### For External AWS Accounts

```hcl
module "msk" {
  source = "./aws-modules/kafka"
  
  # ... other configuration ...
  
  producer_assume_role_arns = [
    "arn:aws:iam::111111111111:role/external-producer-role"
  ]
  
  consumer_assume_role_arns = [
    "arn:aws:iam::222222222222:role/external-consumer-role"
  ]
}
```

## Client Configuration

### Java/Kafka Clients

```java
Properties props = new Properties();
props.put("bootstrap.servers", "<bootstrap_brokers_sasl_iam>");
props.put("security.protocol", "SASL_SSL");
props.put("sasl.mechanism", "AWS_MSK_IAM");
props.put("sasl.jaas.config", "software.amazon.msk.auth.iam.IAMLoginModule required;");
props.put("sasl.client.callback.handler.class", 
          "software.amazon.msk.auth.iam.IAMClientCallbackHandler");

// Producer
KafkaProducer<String, String> producer = new KafkaProducer<>(props);
producer.send(new ProducerRecord<>("myapp-orders", "key", "value"));

// Consumer
props.put("group.id", "cg-myapp-processor");
KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);
consumer.subscribe(Collections.singletonList("myapp-orders"));
```

### Python

```python
from kafka import KafkaProducer, KafkaConsumer
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider

class MSKTokenProvider:
    def token(self):
        token, _ = MSKAuthTokenProvider.generate_auth_token('us-east-1')
        return token

tp = MSKTokenProvider()

# Producer
producer = KafkaProducer(
    bootstrap_servers='<bootstrap_brokers_sasl_iam>',
    security_protocol='SASL_SSL',
    sasl_mechanism='OAUTHBEARER',
    sasl_oauth_token_provider=tp,
)
producer.send('myapp-orders', b'message')

# Consumer
consumer = KafkaConsumer(
    'myapp-orders',
    bootstrap_servers='<bootstrap_brokers_sasl_iam>',
    security_protocol='SASL_SSL',
    sasl_mechanism='OAUTHBEARER',
    sasl_oauth_token_provider=tp,
    group_id='cg-myapp-processor'
)
```

### Node.js

```javascript
const { Kafka } = require('kafkajs');
const { KafkaJSIAMAuth } = require('@aws-msk/kafkajs-iam-auth');

const kafka = new Kafka({
  clientId: 'my-app',
  brokers: ['<bootstrap_brokers_sasl_iam>'],
  ssl: true,
  sasl: {
    mechanism: 'oauthbearer',
    oauthBearerProvider: KafkaJSIAMAuth({
      region: 'us-east-1'
    })
  }
});

// Producer
const producer = kafka.producer();
await producer.connect();
await producer.send({
  topic: 'myapp-orders',
  messages: [{ value: 'Hello' }]
});

// Consumer
const consumer = kafka.consumer({ groupId: 'cg-myapp-processor' });
await consumer.connect();
await consumer.subscribe({ topic: 'myapp-orders' });
```

## Validation and Testing

### Test Topic Creation

```bash
# This will succeed (matches prefix)
kafka-topics.sh --create \
  --bootstrap-server <bootstrap_brokers_sasl_iam> \
  --command-config client.properties \
  --topic myapp-orders \
  --partitions 3 \
  --replication-factor 3

# This will fail (doesn't match prefix)
kafka-topics.sh --create \
  --bootstrap-server <bootstrap_brokers_sasl_iam> \
  --command-config client.properties \
  --topic orders \
  --partitions 3 \
  --replication-factor 3
# Error: Not authorized to create topic 'orders'
```

### Test Producer Access

```bash
# This will succeed
echo "test message" | kafka-console-producer.sh \
  --bootstrap-server <bootstrap_brokers_sasl_iam> \
  --producer.config client.properties \
  --topic myapp-orders

# This will fail
echo "test message" | kafka-console-producer.sh \
  --bootstrap-server <bootstrap_brokers_sasl_iam> \
  --producer.config client.properties \
  --topic orders
# Error: Not authorized to write to topic 'orders'
```

### Test Consumer Access

```bash
# This will succeed
kafka-console-consumer.sh \
  --bootstrap-server <bootstrap_brokers_sasl_iam> \
  --consumer.config client.properties \
  --topic myapp-orders \
  --group cg-myapp-processor

# This will fail (wrong topic prefix)
kafka-console-consumer.sh \
  --bootstrap-server <bootstrap_brokers_sasl_iam> \
  --consumer.config client.properties \
  --topic orders \
  --group cg-myapp-processor
# Error: Not authorized to read from topic 'orders'

# This will fail (wrong consumer group prefix)
kafka-console-consumer.sh \
  --bootstrap-server <bootstrap_brokers_sasl_iam> \
  --consumer.config client.properties \
  --topic myapp-orders \
  --group processor
# Error: Not authorized to join group 'processor'
```

## Best Practices

### 1. Choose Meaningful Prefixes
- Use prefixes that clearly identify the environment, application, or team
- Keep prefixes short but descriptive
- Use hyphens for readability: `prod-ecommerce-` instead of `prodecommerce`

### 2. Document Your Naming Convention
- Create a naming convention guide for your team
- Include examples of valid and invalid topic names
- Document the purpose of different topic categories

### 3. Use Hierarchical Naming
```
{environment}-{application}-{domain}-{entity}

Examples:
- prod-ecommerce-orders-created
- prod-ecommerce-orders-updated
- prod-ecommerce-payments-processed
- staging-analytics-events-clickstream
```

### 4. Separate Concerns
- Use different prefixes for different applications
- Consider separate clusters for different environments
- Use consumer group prefixes to identify different consumer types

### 5. Plan for Multi-Tenancy
```hcl
# Tenant A
topic_naming_prefix = "tenant-a-"

# Tenant B
topic_naming_prefix = "tenant-b-"
```

### 6. Disable Auto-Create Topics
```hcl
auto_create_topics_enable = false
```
This forces explicit topic creation and prevents typos from creating unintended topics.

## Troubleshooting

### Error: "Not authorized to create topic"
- **Cause**: Topic name doesn't match the required prefix
- **Solution**: Ensure topic name starts with `${topic_naming_prefix}`

### Error: "Not authorized to write to topic"
- **Cause**: Using consumer role to produce, or topic name doesn't match prefix
- **Solution**: Use producer role and verify topic name

### Error: "Not authorized to join group"
- **Cause**: Consumer group name doesn't match the required prefix
- **Solution**: Ensure group name starts with `${consumer_group_naming_prefix}`

### Error: "Access denied"
- **Cause**: IAM role not properly assumed or attached
- **Solution**: Verify IAM role is attached to your compute resource

## Monitoring and Auditing

### CloudWatch Metrics
Monitor unauthorized access attempts:
```
Metric: ClientAuthenticationFailures
Dimension: Cluster Name
```

### CloudTrail Logs
Audit IAM role assumptions and Kafka API calls:
```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceType,AttributeValue=AWS::Kafka::Cluster
```

### MSK Broker Logs
Review broker logs in CloudWatch for authorization failures:
```
Log Group: /aws/msk/{cluster-name}
Filter Pattern: "AUTHORIZATION_FAILED"
```

## Migration Guide

### Migrating Existing Topics

If you have existing topics that don't follow the naming convention:

1. **Create new topics with proper naming**:
   ```bash
   kafka-topics.sh --create --topic myapp-orders ...
   ```

2. **Use MirrorMaker 2 to migrate data**:
   ```bash
   kafka-mirror-maker.sh --consumer.config source.properties \
                         --producer.config target.properties \
                         --whitelist "orders" \
                         --rename-topics "orders:myapp-orders"
   ```

3. **Update applications to use new topic names**

4. **Decommission old topics after verification**

## Summary

The MSK module's IAM-based topic naming enforcement provides:
- ✅ Infrastructure-level security
- ✅ Consistent naming across teams
- ✅ Prevention of unauthorized topic creation
- ✅ Clear separation between applications
- ✅ Audit trail through CloudTrail
- ✅ No application code changes required

By enforcing naming conventions at the IAM level, you ensure compliance without relying on application-level controls.
