# MSK (Managed Streaming for Kafka) Terraform Module

This module provisions an AWS MSK cluster with security best practices, IAM-based topic naming conventions, and minimal port exposure.

## Features

- ✅ **VPC Integration**: Takes VPC ID and subnet IDs as parameters
- ✅ **Security Groups**: Only opens necessary Kafka ports based on authentication method
- ✅ **IAM Authentication**: Enforces topic naming conventions through IAM policies
- ✅ **Encryption**: Supports encryption in transit (TLS) and at rest (KMS)
- ✅ **Logging**: CloudWatch, Kinesis Firehose, and S3 logging options
- ✅ **Monitoring**: Optional JMX and Node Exporter support
- ✅ **Topic Naming Convention**: Enforces prefixes for topics and consumer groups via IAM

## Security Features

### Port Restrictions
The module only opens ports that are necessary based on your configuration:
- **9092**: Kafka plaintext (only if `encryption_in_transit_client_broker = "PLAINTEXT"`)
- **9094**: Kafka TLS (only if TLS is enabled)
- **9096**: Kafka SASL/SCRAM (only if `enable_scram_auth = true`)
- **9098**: Kafka IAM authentication (only if `enable_iam_auth = true`)
- **2181**: Zookeeper (only for internal cluster communication)
- **11001**: JMX Exporter (only if `enable_jmx_exporter = true`)
- **11002**: Node Exporter (only if `enable_node_exporter = true`)

### IAM-Based Topic Naming Convention
The module creates IAM roles that enforce topic naming conventions:
- **Producer Role**: Can only create/write to topics matching `${topic_naming_prefix}*`
- **Consumer Role**: Can only read from topics matching `${topic_naming_prefix}*`
- **Admin Role**: Full access but still follows naming conventions

This prevents unauthorized topic creation and ensures consistent naming across your organization.

## Usage

### Basic Example

```hcl
module "msk_cluster" {
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
  broker_volume_size     = 100

  # Security configuration
  encryption_in_transit_client_broker = "TLS"
  enable_iam_auth                     = true
  
  # Topic naming convention
  topic_naming_prefix           = "myapp-"
  consumer_group_naming_prefix  = "cg-myapp-"

  tags = {
    Environment = "production"
    Project     = "my-project"
  }
}
```

### Advanced Example with Custom IAM

```hcl
module "msk_cluster" {
  source = "./aws-modules/kafka"

  cluster_name = "production-kafka"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.subnet_ids
  vpc_cidr     = "192.168.0.0/16"

  # Cluster configuration
  kafka_version          = "3.5.1"
  number_of_broker_nodes = 6
  broker_instance_type   = "kafka.m5.xlarge"
  broker_volume_size     = 500
  
  enable_provisioned_throughput = true
  volume_throughput            = 250

  # Security
  encryption_in_transit_client_broker = "TLS"
  encryption_in_transit_in_cluster    = true
  kms_key_arn                        = aws_kms_key.msk.arn
  enable_iam_auth                    = true
  
  # Network security
  allowed_cidr_blocks          = "192.168.0.0/16"
  create_client_security_group = true

  # Logging
  enable_cloudwatch_logs        = true
  cloudwatch_log_retention_days = 30
  enable_s3_logs               = true
  s3_logs_bucket               = "my-msk-logs-bucket"
  s3_logs_prefix               = "kafka-logs/"

  # Kafka configuration
  auto_create_topics_enable   = false
  default_replication_factor  = 3
  min_insync_replicas        = 2
  num_partitions             = 6

  # Topic naming convention
  topic_naming_prefix          = "prod-"
  consumer_group_naming_prefix = "cg-prod-"

  # IAM roles
  create_producer_role = true
  create_consumer_role = true
  create_admin_role    = true
  
  producer_assume_role_arns = [
    "arn:aws:iam::123456789012:role/my-app-role"
  ]
  
  consumer_assume_role_arns = [
    "arn:aws:iam::123456789012:role/my-consumer-role"
  ]

  tags = {
    Environment = "production"
    Project     = "my-project"
    ManagedBy   = "terraform"
  }
}
```

## Inputs

### Required Inputs

| Name | Description | Type |
|------|-------------|------|
| `cluster_name` | Name of the MSK cluster | `string` |
| `vpc_id` | VPC ID where the MSK cluster will be deployed | `string` |
| `subnet_ids` | List of subnet IDs (minimum 2, in different AZs) | `list(string)` |
| `vpc_cidr` | CIDR block of the VPC | `string` |

### Optional Inputs

See [variables.tf](./variables.tf) for a complete list of optional inputs with descriptions and defaults.

## Outputs

### Connection Outputs

| Name | Description |
|------|-------------|
| `cluster_arn` | ARN of the MSK cluster |
| `bootstrap_brokers_tls` | TLS connection host:port pairs |
| `bootstrap_brokers_sasl_iam` | IAM authentication connection host:port pairs |
| `zookeeper_connect_string` | Zookeeper connection string |

### Security Outputs

| Name | Description |
|------|-------------|
| `security_group_id` | ID of the MSK cluster security group |
| `client_security_group_id` | ID of the client security group |
| `producer_role_arn` | ARN of the producer IAM role |
| `consumer_role_arn` | ARN of the consumer IAM role |
| `admin_role_arn` | ARN of the admin IAM role |

### Naming Convention Outputs

| Name | Description |
|------|-------------|
| `topic_naming_prefix` | Required prefix for all topics |
| `consumer_group_naming_prefix` | Required prefix for all consumer groups |

## Topic Naming Convention Enforcement

The module enforces topic naming conventions through IAM policies. Here's how it works:

1. **Producer Role**: Can only create and write to topics that start with `${topic_naming_prefix}`
2. **Consumer Role**: Can only read from topics that start with `${topic_naming_prefix}`
3. **Consumer Groups**: Must start with `${consumer_group_naming_prefix}`

### Example

If you set:
```hcl
topic_naming_prefix          = "myapp-"
consumer_group_naming_prefix = "cg-myapp-"
```

Then:
- ✅ Valid topic names: `myapp-orders`, `myapp-payments`, `myapp-users`
- ❌ Invalid topic names: `orders`, `payments`, `other-app-orders`
- ✅ Valid consumer groups: `cg-myapp-processor`, `cg-myapp-analytics`
- ❌ Invalid consumer groups: `processor`, `cg-other-app`

## Connecting to the Cluster

### Using IAM Authentication

1. **Assume the appropriate role** (producer, consumer, or admin)
2. **Use the IAM bootstrap brokers**:
   ```
   bootstrap_brokers_sasl_iam = "b-1.mycluster.xxx.kafka.us-east-1.amazonaws.com:9098,..."
   ```

3. **Configure your Kafka client** with AWS IAM authentication:

```properties
# Kafka client configuration
security.protocol=SASL_SSL
sasl.mechanism=AWS_MSK_IAM
sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;
sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler
```

### Python Example

```python
from kafka import KafkaProducer
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider

def get_producer():
    return KafkaProducer(
        bootstrap_servers='<bootstrap_brokers_sasl_iam>',
        security_protocol='SASL_SSL',
        sasl_mechanism='OAUTHBEARER',
        sasl_oauth_token_provider=MSKAuthTokenProvider(region='us-east-1'),
        value_serializer=lambda v: json.dumps(v).encode('utf-8')
    )

# Create topics following naming convention
producer = get_producer()
producer.send('myapp-orders', {'order_id': '123'})
```

## Best Practices

1. **Use IAM Authentication**: Set `enable_iam_auth = true` for fine-grained access control
2. **Enable TLS**: Set `encryption_in_transit_client_broker = "TLS"`
3. **Disable Auto-Create Topics**: Set `auto_create_topics_enable = false` to control topic creation
4. **Use Multiple AZs**: Deploy brokers across at least 2 availability zones
5. **Enable Logging**: Use CloudWatch logs for monitoring and troubleshooting
6. **Set Replication Factor**: Use `default_replication_factor = 3` for production
7. **Configure Min In-Sync Replicas**: Set `min_insync_replicas = 2` for data durability
8. **Use Client Security Group**: Set `create_client_security_group = true` for better network isolation

## Monitoring

The module supports multiple monitoring options:

1. **CloudWatch Logs**: Enable with `enable_cloudwatch_logs = true`
2. **CloudWatch Metrics**: Automatically available for MSK clusters
3. **JMX Exporter**: Enable with `enable_jmx_exporter = true`
4. **Node Exporter**: Enable with `enable_node_exporter = true`

## Cost Optimization

- Start with smaller instance types (`kafka.m5.large`) and scale up as needed
- Use standard EBS volumes unless you need provisioned throughput
- Set appropriate CloudWatch log retention periods
- Consider using fewer broker nodes for development environments

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |

## License

This module is provided as-is for use within your organization.
