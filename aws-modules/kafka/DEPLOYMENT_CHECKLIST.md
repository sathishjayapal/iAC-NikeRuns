# MSK Module Deployment Checklist

Use this checklist to ensure a successful MSK cluster deployment.

## Pre-Deployment Checklist

### Infrastructure Prerequisites
- [ ] VPC exists with CIDR block documented
- [ ] At least 2 subnets in different availability zones
- [ ] Subnets have appropriate route tables configured
- [ ] AWS CLI configured with appropriate credentials
- [ ] Terraform >= 1.0 installed
- [ ] AWS provider >= 5.0 configured

### Planning
- [ ] Cluster name decided (must be unique in region)
- [ ] Kafka version selected (recommend: 3.5.1)
- [ ] Number of broker nodes determined (minimum 2, recommend 3)
- [ ] Instance type selected based on workload
- [ ] Storage size calculated based on retention needs
- [ ] Topic naming convention defined
- [ ] Consumer group naming convention defined

### Security Planning
- [ ] Encryption requirements documented
- [ ] IAM authentication strategy defined
- [ ] KMS key created (if using custom encryption)
- [ ] Network access requirements documented
- [ ] Allowed CIDR blocks identified

### Monitoring Planning
- [ ] CloudWatch log retention period decided
- [ ] S3 bucket created (if using S3 logging)
- [ ] Monitoring tools identified (CloudWatch, Prometheus, etc.)
- [ ] Alerting strategy defined

## Configuration Checklist

### Required Variables
- [ ] `cluster_name` - Set to unique cluster name
- [ ] `vpc_id` - Set to existing VPC ID
- [ ] `subnet_ids` - Set to list of subnet IDs (minimum 2)
- [ ] `vpc_cidr` - Set to VPC CIDR block

### Cluster Configuration
- [ ] `kafka_version` - Kafka version selected
- [ ] `number_of_broker_nodes` - Number of brokers (multiple of AZ count)
- [ ] `broker_instance_type` - Instance type selected
- [ ] `broker_volume_size` - Storage size in GB

### Security Configuration
- [ ] `encryption_in_transit_client_broker` - Set to "TLS" (recommended)
- [ ] `encryption_in_transit_in_cluster` - Set to true (recommended)
- [ ] `enable_iam_auth` - Set to true (recommended)
- [ ] `kms_key_arn` - Set if using custom KMS key
- [ ] `allowed_cidr_blocks` - Set if restricting access beyond VPC

### Naming Convention
- [ ] `topic_naming_prefix` - Set to organization standard
- [ ] `consumer_group_naming_prefix` - Set to organization standard

### IAM Configuration
- [ ] `create_producer_role` - Set to true if needed
- [ ] `create_consumer_role` - Set to true if needed
- [ ] `create_admin_role` - Set to true if needed
- [ ] `producer_assume_role_arns` - Set if cross-account access needed
- [ ] `consumer_assume_role_arns` - Set if cross-account access needed

### Logging Configuration
- [ ] `enable_cloudwatch_logs` - Set to true (recommended)
- [ ] `cloudwatch_log_retention_days` - Set retention period
- [ ] `enable_s3_logs` - Set to true if long-term storage needed
- [ ] `s3_logs_bucket` - Set if S3 logging enabled

### Kafka Configuration
- [ ] `auto_create_topics_enable` - Set to false (recommended for production)
- [ ] `default_replication_factor` - Set to 3 (recommended)
- [ ] `min_insync_replicas` - Set to 2 (recommended)
- [ ] `num_partitions` - Set based on throughput needs

### Tags
- [ ] `tags` - Set organization-required tags
  - [ ] Environment tag
  - [ ] Project tag
  - [ ] Owner tag
  - [ ] Cost center tag

## Deployment Checklist

### Pre-Deployment Validation
- [ ] Run `terraform init` successfully
- [ ] Run `terraform validate` successfully
- [ ] Run `terraform plan` and review output
- [ ] Verify estimated costs are acceptable
- [ ] Confirm no unexpected resource changes
- [ ] Review security group rules in plan
- [ ] Review IAM policies in plan

### Deployment
- [ ] Run `terraform apply`
- [ ] Review apply plan one final time
- [ ] Type "yes" to confirm
- [ ] Wait for cluster creation (15-20 minutes)
- [ ] Verify no errors in output
- [ ] Note down output values

### Post-Deployment Validation
- [ ] Cluster status is ACTIVE in AWS Console
- [ ] Bootstrap brokers are accessible
- [ ] Security groups created correctly
- [ ] IAM roles created correctly
- [ ] CloudWatch log group created
- [ ] CloudWatch metrics appearing

## Application Integration Checklist

### IAM Role Setup
- [ ] Producer role attached to producer applications
- [ ] Consumer role attached to consumer applications
- [ ] Admin role attached to admin tools
- [ ] Roles can be assumed successfully

### Client Configuration
- [ ] Kafka client library installed
- [ ] IAM authentication library installed
- [ ] Client configuration file created
- [ ] Bootstrap brokers configured
- [ ] Security protocol set to SASL_SSL
- [ ] SASL mechanism set to AWS_MSK_IAM

### Topic Creation
- [ ] Admin access configured
- [ ] Topic creation script prepared
- [ ] Topics follow naming convention
- [ ] Partition count appropriate for workload
- [ ] Replication factor set correctly
- [ ] Topics created successfully

### Producer Testing
- [ ] Producer application configured
- [ ] Producer can connect to cluster
- [ ] Producer can create topics (if allowed)
- [ ] Producer can write messages
- [ ] Messages appear in topic
- [ ] No authorization errors

### Consumer Testing
- [ ] Consumer application configured
- [ ] Consumer can connect to cluster
- [ ] Consumer can join consumer group
- [ ] Consumer can read messages
- [ ] Consumer group appears in cluster
- [ ] No authorization errors

### Naming Convention Testing
- [ ] Test topic creation with correct prefix (should succeed)
- [ ] Test topic creation with wrong prefix (should fail)
- [ ] Test consumer group with correct prefix (should succeed)
- [ ] Test consumer group with wrong prefix (should fail)
- [ ] Verify authorization errors are clear

## Monitoring Setup Checklist

### CloudWatch Logs
- [ ] Log group exists: `/aws/msk/{cluster-name}`
- [ ] Broker logs appearing
- [ ] Log retention set correctly
- [ ] No error logs appearing

### CloudWatch Metrics
- [ ] Metrics appearing in CloudWatch
- [ ] Key metrics identified:
  - [ ] BytesInPerSec
  - [ ] BytesOutPerSec
  - [ ] MessagesInPerSec
  - [ ] FetchConsumerTotalTimeMs
  - [ ] ProduceTotalTimeMs

### CloudWatch Alarms (Recommended)
- [ ] High CPU utilization alarm
- [ ] High memory utilization alarm
- [ ] High disk utilization alarm
- [ ] Authentication failure alarm
- [ ] Offline partitions alarm

### Dashboards
- [ ] CloudWatch dashboard created
- [ ] Key metrics added to dashboard
- [ ] Dashboard shared with team

## Security Validation Checklist

### Network Security
- [ ] Security group rules reviewed
- [ ] Only necessary ports open
- [ ] Source CIDR blocks correct
- [ ] No public internet access
- [ ] VPC endpoints configured (if needed)

### IAM Security
- [ ] IAM policies follow least privilege
- [ ] Topic naming restrictions working
- [ ] Consumer group naming restrictions working
- [ ] Cross-account access working (if configured)
- [ ] No overly permissive policies

### Encryption
- [ ] Encryption in transit enabled
- [ ] Encryption at rest enabled
- [ ] KMS key permissions correct
- [ ] TLS version is 1.2 or higher

### Audit Logging
- [ ] CloudTrail logging enabled
- [ ] MSK API calls being logged
- [ ] IAM role assumptions being logged
- [ ] Log retention appropriate

## Documentation Checklist

### Technical Documentation
- [ ] Cluster configuration documented
- [ ] Connection details documented
- [ ] IAM role ARNs documented
- [ ] Topic naming convention documented
- [ ] Consumer group naming convention documented

### Operational Documentation
- [ ] Runbook created for common operations
- [ ] Troubleshooting guide created
- [ ] Escalation procedures documented
- [ ] Backup and recovery procedures documented

### Application Documentation
- [ ] Client configuration examples documented
- [ ] Code examples provided
- [ ] Error handling documented
- [ ] Best practices documented

## Operational Readiness Checklist

### Backup and Recovery
- [ ] Backup strategy defined
- [ ] S3 logging configured (if needed)
- [ ] Recovery procedures tested
- [ ] RTO/RPO documented

### Scaling
- [ ] Scaling triggers identified
- [ ] Scaling procedures documented
- [ ] Vertical scaling tested
- [ ] Horizontal scaling tested

### Maintenance
- [ ] Maintenance windows defined
- [ ] Update procedures documented
- [ ] Rollback procedures documented
- [ ] Change management process defined

### Incident Response
- [ ] On-call rotation defined
- [ ] Incident response procedures documented
- [ ] Communication plan defined
- [ ] Post-mortem template created

## Performance Testing Checklist

### Load Testing
- [ ] Load testing tools identified
- [ ] Baseline performance measured
- [ ] Peak load tested
- [ ] Sustained load tested
- [ ] Performance metrics documented

### Latency Testing
- [ ] Producer latency measured
- [ ] Consumer latency measured
- [ ] End-to-end latency measured
- [ ] Latency SLAs defined

### Throughput Testing
- [ ] Maximum throughput measured
- [ ] Throughput per partition measured
- [ ] Network bandwidth tested
- [ ] Throughput SLAs defined

## Cost Optimization Checklist

### Initial Cost Review
- [ ] Monthly cost estimated
- [ ] Cost breakdown by component:
  - [ ] Broker instances
  - [ ] Storage
  - [ ] Data transfer
  - [ ] CloudWatch logs
- [ ] Cost compared to budget

### Optimization Opportunities
- [ ] Right-sized instance types
- [ ] Appropriate storage size
- [ ] Log retention optimized
- [ ] Data transfer minimized
- [ ] Reserved instances considered (for production)

### Cost Monitoring
- [ ] Cost allocation tags applied
- [ ] AWS Cost Explorer configured
- [ ] Budget alerts configured
- [ ] Monthly cost review scheduled

## Compliance Checklist

### Security Compliance
- [ ] Encryption requirements met
- [ ] Access control requirements met
- [ ] Audit logging requirements met
- [ ] Network isolation requirements met

### Data Compliance
- [ ] Data retention requirements met
- [ ] Data residency requirements met
- [ ] Data classification documented
- [ ] PII handling procedures documented

### Operational Compliance
- [ ] Change management followed
- [ ] Documentation requirements met
- [ ] Approval process followed
- [ ] Compliance audit trail maintained

## Sign-Off Checklist

### Technical Sign-Off
- [ ] Infrastructure team approval
- [ ] Security team approval
- [ ] Network team approval
- [ ] Application team approval

### Business Sign-Off
- [ ] Project manager approval
- [ ] Budget approval
- [ ] Compliance approval
- [ ] Executive approval (if required)

### Go-Live Checklist
- [ ] All testing completed
- [ ] All documentation completed
- [ ] All approvals obtained
- [ ] Rollback plan ready
- [ ] Support team notified
- [ ] Monitoring confirmed
- [ ] Communication sent to stakeholders

## Post-Deployment Checklist

### Day 1
- [ ] Monitor cluster health
- [ ] Monitor application logs
- [ ] Monitor CloudWatch metrics
- [ ] Monitor CloudWatch alarms
- [ ] Address any issues immediately

### Week 1
- [ ] Review performance metrics
- [ ] Review cost metrics
- [ ] Review security logs
- [ ] Gather feedback from developers
- [ ] Address any issues

### Month 1
- [ ] Conduct performance review
- [ ] Conduct cost review
- [ ] Conduct security review
- [ ] Update documentation based on learnings
- [ ] Plan optimizations

## Troubleshooting Checklist

### Connection Issues
- [ ] Verify bootstrap brokers
- [ ] Verify security group rules
- [ ] Verify IAM role attached
- [ ] Verify client configuration
- [ ] Check CloudWatch logs

### Authentication Issues
- [ ] Verify IAM role permissions
- [ ] Verify IAM authentication library
- [ ] Verify SASL mechanism
- [ ] Check CloudTrail logs
- [ ] Check broker logs

### Authorization Issues
- [ ] Verify topic name matches prefix
- [ ] Verify consumer group name matches prefix
- [ ] Verify IAM policy conditions
- [ ] Check broker logs for authorization failures
- [ ] Review IAM policy

### Performance Issues
- [ ] Check CloudWatch metrics
- [ ] Check broker CPU/memory/disk
- [ ] Check network throughput
- [ ] Check partition distribution
- [ ] Check consumer lag

## Success Criteria

### Technical Success
- [x] Cluster deployed successfully
- [x] All tests passing
- [x] No critical issues
- [x] Performance meets requirements
- [x] Security requirements met

### Business Success
- [x] Within budget
- [x] Meets timeline
- [x] Stakeholder approval
- [x] Documentation complete
- [x] Team trained

---

## Notes Section

Use this space to document any deployment-specific notes, issues encountered, or deviations from the standard process:

```
Date: _______________
Deployed by: _______________
Environment: _______________

Notes:
_____________________________________________________________________________
_____________________________________________________________________________
_____________________________________________________________________________
_____________________________________________________________________________
_____________________________________________________________________________
```

---

**Deployment Status**: [ ] Not Started | [ ] In Progress | [ ] Completed | [ ] Failed

**Deployment Date**: _______________

**Deployed By**: _______________

**Approved By**: _______________
