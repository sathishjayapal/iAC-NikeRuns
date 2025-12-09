# MSK Module Quick Start Guide

Get your MSK cluster up and running in minutes with this quick start guide.

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- Existing VPC with at least 2 subnets in different availability zones

## Step 1: Basic Setup

Create a new Terraform configuration file (e.g., `msk.tf`):

```hcl
# Configure AWS provider
provider "aws" {
  region = "us-east-1"
}

# Use existing VPC module or reference existing VPC
module "vpc" {
  source = "./aws-modules/vpc"
  
  region         = "us-east-1"
  name_prefix    = "my-app"
  vpc_cidr       = "192.168.0.0/16"
  subnet01_cidr  = "192.168.64.0/18"
  subnet02_cidr  = "192.168.128.0/18"
  subnet03_cidr  = "192.168.192.0/18"
}

# Create MSK cluster
module "msk" {
  source = "./aws-modules/kafka"

  # Required parameters
  cluster_name = "my-kafka-cluster"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.subnet_ids
  vpc_cidr     = "192.168.0.0/16"

  # Cluster configuration
  kafka_version          = "3.5.1"
  number_of_broker_nodes = 3
  broker_instance_type   = "kafka.m5.large"

  # Security
  encryption_in_transit_client_broker = "TLS"
  enable_iam_auth                     = true

  # Topic naming convention
  topic_naming_prefix          = "myapp-"
  consumer_group_naming_prefix = "cg-myapp-"

  tags = {
    Environment = "development"
    ManagedBy   = "terraform"
  }
}

# Output connection information
output "msk_bootstrap_brokers" {
  value     = module.msk.bootstrap_brokers_sasl_iam
  sensitive = true
}

output "msk_producer_role_arn" {
  value = module.msk.producer_role_arn
}

output "msk_consumer_role_arn" {
  value = module.msk.consumer_role_arn
}
```

## Step 2: Deploy the Cluster

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

The cluster will take approximately 15-20 minutes to provision.

## Step 3: Get Connection Details

```bash
# Get bootstrap brokers
terraform output msk_bootstrap_brokers

# Get IAM role ARNs
terraform output msk_producer_role_arn
terraform output msk_consumer_role_arn
```

## Step 4: Configure Your Application

### For EC2 Instances

1. **Attach the IAM role to your EC2 instance**:
```bash
aws ec2 associate-iam-instance-profile \
  --instance-id i-xxxxx \
  --iam-instance-profile Name=kafka-producer-profile
```

2. **Install Kafka client**:
```bash
wget https://archive.apache.org/dist/kafka/3.5.1/kafka_2.13-3.5.1.tgz
tar -xzf kafka_2.13-3.5.1.tgz
cd kafka_2.13-3.5.1
```

3. **Create client configuration** (`client.properties`):
```properties
security.protocol=SASL_SSL
sasl.mechanism=AWS_MSK_IAM
sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;
sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler
```

4. **Download the IAM authentication library**:
```bash
wget https://github.com/aws/aws-msk-iam-auth/releases/download/v1.1.6/aws-msk-iam-auth-1.1.6-all.jar
export CLASSPATH=./aws-msk-iam-auth-1.1.6-all.jar
```

## Step 5: Test the Connection

### Create a Topic

```bash
bin/kafka-topics.sh --create \
  --bootstrap-server <bootstrap_brokers> \
  --command-config client.properties \
  --topic myapp-test \
  --partitions 3 \
  --replication-factor 3
```

### Produce Messages

```bash
bin/kafka-console-producer.sh \
  --bootstrap-server <bootstrap_brokers> \
  --producer.config client.properties \
  --topic myapp-test
```

Type some messages and press Enter after each one.

### Consume Messages

```bash
bin/kafka-console-consumer.sh \
  --bootstrap-server <bootstrap_brokers> \
  --consumer.config client.properties \
  --topic myapp-test \
  --group cg-myapp-test \
  --from-beginning
```

## Step 6: Application Integration

### Python Example

```python
# Install dependencies
pip install kafka-python aws-msk-iam-sasl-signer

# producer.py
from kafka import KafkaProducer
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider
import json

class MSKTokenProvider:
    def token(self):
        token, _ = MSKAuthTokenProvider.generate_auth_token('us-east-1')
        return token

producer = KafkaProducer(
    bootstrap_servers='<bootstrap_brokers>',
    security_protocol='SASL_SSL',
    sasl_mechanism='OAUTHBEARER',
    sasl_oauth_token_provider=MSKTokenProvider(),
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

# Send message
producer.send('myapp-orders', {'order_id': '123', 'amount': 99.99})
producer.flush()
```

### Java Example

```java
// Add dependencies to pom.xml
<dependency>
    <groupId>org.apache.kafka</groupId>
    <artifactId>kafka-clients</artifactId>
    <version>3.5.1</version>
</dependency>
<dependency>
    <groupId>software.amazon.msk</groupId>
    <artifactId>aws-msk-iam-auth</artifactId>
    <version>1.1.6</version>
</dependency>

// Producer.java
Properties props = new Properties();
props.put("bootstrap.servers", "<bootstrap_brokers>");
props.put("security.protocol", "SASL_SSL");
props.put("sasl.mechanism", "AWS_MSK_IAM");
props.put("sasl.jaas.config", "software.amazon.msk.auth.iam.IAMLoginModule required;");
props.put("sasl.client.callback.handler.class", 
          "software.amazon.msk.auth.iam.IAMClientCallbackHandler");
props.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
props.put("value.serializer", "org.apache.kafka.common.serialization.StringSerializer");

KafkaProducer<String, String> producer = new KafkaProducer<>(props);
producer.send(new ProducerRecord<>("myapp-orders", "key", "value"));
producer.close();
```

### Node.js Example

```javascript
// Install dependencies
npm install kafkajs @aws-msk/kafkajs-iam-auth

// producer.js
const { Kafka } = require('kafkajs');
const { KafkaJSIAMAuth } = require('@aws-msk/kafkajs-iam-auth');

const kafka = new Kafka({
  clientId: 'my-app',
  brokers: ['<bootstrap_brokers>'],
  ssl: true,
  sasl: {
    mechanism: 'oauthbearer',
    oauthBearerProvider: KafkaJSIAMAuth({
      region: 'us-east-1'
    })
  }
});

const producer = kafka.producer();

async function sendMessage() {
  await producer.connect();
  await producer.send({
    topic: 'myapp-orders',
    messages: [
      { key: 'key1', value: 'Hello Kafka!' }
    ]
  });
  await producer.disconnect();
}

sendMessage();
```

## Common Issues and Solutions

### Issue: "Not authorized to create topic"
**Solution**: Ensure your topic name starts with the configured prefix (e.g., `myapp-`)

### Issue: "Connection timeout"
**Solution**: 
- Verify security group rules allow traffic from your client
- Check that subnets have proper routing
- Ensure IAM role is attached to your compute resource

### Issue: "Authentication failed"
**Solution**:
- Verify IAM role has correct permissions
- Ensure you're using the correct bootstrap brokers (SASL_IAM endpoint)
- Check that the IAM authentication library is in your classpath

### Issue: "Topic already exists"
**Solution**: Use `--if-not-exists` flag or check existing topics first:
```bash
bin/kafka-topics.sh --list \
  --bootstrap-server <bootstrap_brokers> \
  --command-config client.properties
```

## Next Steps

1. **Review Security**: Check the [README.md](./README.md) for security best practices
2. **Topic Naming**: Read [TOPIC_NAMING_GUIDE.md](./TOPIC_NAMING_GUIDE.md) for naming conventions
3. **Monitoring**: Set up CloudWatch dashboards and alarms
4. **Scaling**: Adjust broker count and instance types based on load
5. **Backup**: Configure S3 logging for audit trails

## Useful Commands

### List Topics
```bash
bin/kafka-topics.sh --list \
  --bootstrap-server <bootstrap_brokers> \
  --command-config client.properties
```

### Describe Topic
```bash
bin/kafka-topics.sh --describe \
  --bootstrap-server <bootstrap_brokers> \
  --command-config client.properties \
  --topic myapp-orders
```

### List Consumer Groups
```bash
bin/kafka-consumer-groups.sh --list \
  --bootstrap-server <bootstrap_brokers> \
  --command-config client.properties
```

### Describe Consumer Group
```bash
bin/kafka-consumer-groups.sh --describe \
  --bootstrap-server <bootstrap_brokers> \
  --command-config client.properties \
  --group cg-myapp-processor
```

### Check Cluster Info
```bash
bin/kafka-broker-api-versions.sh \
  --bootstrap-server <bootstrap_brokers> \
  --command-config client.properties
```

## Cleanup

To destroy the cluster:

```bash
terraform destroy
```

**Warning**: This will permanently delete the cluster and all data. Make sure to backup any important data first.

## Support

For issues or questions:
1. Check the [README.md](./README.md) for detailed documentation
2. Review AWS MSK documentation: https://docs.aws.amazon.com/msk/
3. Check Terraform AWS provider documentation: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/msk_cluster

## Cost Estimate

Approximate monthly cost for the basic setup (3 kafka.m5.large brokers):
- Broker instances: ~$450/month
- Storage (100GB per broker): ~$30/month
- Data transfer: Variable based on usage
- **Total**: ~$480/month + data transfer

For cost optimization, consider:
- Using smaller instance types for development
- Reducing the number of brokers
- Adjusting storage size based on retention needs
