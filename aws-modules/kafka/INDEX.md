# MSK Module Documentation Index

Welcome to the MSK (Managed Streaming for Kafka) Terraform Module documentation. This index will help you navigate to the right documentation for your needs.

## 🚀 Getting Started

**New to this module?** Start here:

1. **[QUICK_START.md](./QUICK_START.md)** - Get your cluster running in minutes
   - Prerequisites
   - Basic setup
   - Deployment steps
   - Testing your connection
   - Application integration examples

2. **[README.md](./README.md)** - Comprehensive module documentation
   - Features overview
   - Security features
   - Usage examples
   - Input/output reference
   - Best practices

## 📚 Core Documentation

### Module Files
- **[main.tf](./main.tf)** - MSK cluster resource and configuration
- **[variables.tf](./variables.tf)** - All configurable parameters
- **[outputs.tf](./outputs.tf)** - Module outputs (connection details, ARNs)
- **[security-groups.tf](./security-groups.tf)** - Security group definitions
- **[iam.tf](./iam.tf)** - IAM roles and policies
- **[versions.tf](./versions.tf)** - Terraform version requirements

### Configuration Files
- **[examples.tf](./examples.tf)** - Multiple usage examples (commented)
- **[.gitignore](./.gitignore)** - Git ignore patterns
- **[.terraform-docs.yml](./.terraform-docs.yml)** - Documentation generator config

## 📖 Detailed Guides

### Architecture and Design
- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - System architecture and component diagrams
  - High-level architecture
  - Component breakdown
  - Data flow diagrams
  - Network architecture
  - Security architecture
  - Monitoring setup

### Topic Naming Conventions
- **[TOPIC_NAMING_GUIDE.md](./TOPIC_NAMING_GUIDE.md)** - Complete guide to naming enforcement
  - How naming enforcement works
  - IAM policy structure
  - Configuration examples
  - Client configuration
  - Testing and validation
  - Troubleshooting

### Deployment
- **[DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md)** - Comprehensive deployment checklist
  - Pre-deployment requirements
  - Configuration checklist
  - Deployment steps
  - Post-deployment validation
  - Monitoring setup
  - Security validation

### Module Summary
- **[MODULE_SUMMARY.md](./MODULE_SUMMARY.md)** - High-level module overview
  - Features implemented
  - File structure
  - Security highlights
  - Integration examples
  - Best practices

## 🎯 Quick Navigation by Task

### I want to...

#### Deploy a new cluster
1. Read [QUICK_START.md](./QUICK_START.md)
2. Review [DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md)
3. Check [examples.tf](./examples.tf) for configuration examples
4. Follow the deployment steps

#### Understand the architecture
1. Read [ARCHITECTURE.md](./ARCHITECTURE.md)
2. Review [README.md](./README.md) security features section
3. Check [security-groups.tf](./security-groups.tf) for network rules
4. Review [iam.tf](./iam.tf) for access control

#### Configure topic naming conventions
1. Read [TOPIC_NAMING_GUIDE.md](./TOPIC_NAMING_GUIDE.md)
2. Review [iam.tf](./iam.tf) policy structure
3. Check [examples.tf](./examples.tf) for naming examples
4. Test with the validation steps

#### Integrate my application
1. Read [QUICK_START.md](./QUICK_START.md) - Application Integration section
2. Review [TOPIC_NAMING_GUIDE.md](./TOPIC_NAMING_GUIDE.md) - Client Configuration section
3. Check [outputs.tf](./outputs.tf) for connection details
4. Follow language-specific examples

#### Troubleshoot issues
1. Check [QUICK_START.md](./QUICK_START.md) - Common Issues section
2. Review [TOPIC_NAMING_GUIDE.md](./TOPIC_NAMING_GUIDE.md) - Troubleshooting section
3. Check [DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md) - Troubleshooting Checklist
4. Review CloudWatch logs

#### Understand security
1. Read [README.md](./README.md) - Security Features section
2. Review [ARCHITECTURE.md](./ARCHITECTURE.md) - Security Architecture
3. Check [security-groups.tf](./security-groups.tf) for network security
4. Review [iam.tf](./iam.tf) for access control

#### Configure monitoring
1. Read [ARCHITECTURE.md](./ARCHITECTURE.md) - Monitoring Architecture
2. Review [variables.tf](./variables.tf) - Logging Configuration section
3. Check [main.tf](./main.tf) - logging_info block
4. Follow [DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md) - Monitoring Setup

#### Optimize costs
1. Read [QUICK_START.md](./QUICK_START.md) - Cost Estimate section
2. Review [MODULE_SUMMARY.md](./MODULE_SUMMARY.md) - Cost Considerations
3. Check [DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md) - Cost Optimization
4. Review [variables.tf](./variables.tf) for cost-related settings

## 📋 Documentation by Role

### For DevOps Engineers
**Primary docs:**
- [DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md)
- [ARCHITECTURE.md](./ARCHITECTURE.md)
- [README.md](./README.md)

**Configuration files:**
- [variables.tf](./variables.tf)
- [security-groups.tf](./security-groups.tf)
- [iam.tf](./iam.tf)

### For Application Developers
**Primary docs:**
- [QUICK_START.md](./QUICK_START.md)
- [TOPIC_NAMING_GUIDE.md](./TOPIC_NAMING_GUIDE.md)

**Reference:**
- [outputs.tf](./outputs.tf)
- [examples.tf](./examples.tf)

### For Security Engineers
**Primary docs:**
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Security Architecture
- [README.md](./README.md) - Security Features

**Configuration files:**
- [security-groups.tf](./security-groups.tf)
- [iam.tf](./iam.tf)

### For Architects
**Primary docs:**
- [ARCHITECTURE.md](./ARCHITECTURE.md)
- [MODULE_SUMMARY.md](./MODULE_SUMMARY.md)
- [README.md](./README.md)

### For Project Managers
**Primary docs:**
- [MODULE_SUMMARY.md](./MODULE_SUMMARY.md)
- [DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md)
- [QUICK_START.md](./QUICK_START.md) - Cost Estimate

## 🔍 Documentation by Topic

### Security
- [README.md](./README.md) - Security Features
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Security Architecture
- [security-groups.tf](./security-groups.tf) - Network Security
- [iam.tf](./iam.tf) - Access Control
- [TOPIC_NAMING_GUIDE.md](./TOPIC_NAMING_GUIDE.md) - Naming Enforcement

### Configuration
- [variables.tf](./variables.tf) - All Variables
- [examples.tf](./examples.tf) - Usage Examples
- [README.md](./README.md) - Configuration Guide

### Networking
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Network Architecture
- [security-groups.tf](./security-groups.tf) - Security Groups
- [README.md](./README.md) - Port Restrictions

### IAM and Access Control
- [iam.tf](./iam.tf) - IAM Resources
- [TOPIC_NAMING_GUIDE.md](./TOPIC_NAMING_GUIDE.md) - Complete Guide
- [ARCHITECTURE.md](./ARCHITECTURE.md) - IAM Architecture

### Monitoring and Logging
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Monitoring Architecture
- [main.tf](./main.tf) - Logging Configuration
- [DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md) - Monitoring Setup

### Deployment
- [QUICK_START.md](./QUICK_START.md) - Quick Deployment
- [DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md) - Comprehensive Checklist
- [examples.tf](./examples.tf) - Configuration Examples

## 📊 File Size Reference

| File | Size | Purpose |
|------|------|---------|
| ARCHITECTURE.md | 15 KB | Architecture diagrams and flows |
| DEPLOYMENT_CHECKLIST.md | 13 KB | Deployment validation checklist |
| TOPIC_NAMING_GUIDE.md | 12 KB | Topic naming enforcement guide |
| MODULE_SUMMARY.md | 11 KB | Module overview and summary |
| QUICK_START.md | 9 KB | Getting started guide |
| README.md | 9 KB | Main documentation |
| variables.tf | 9 KB | Input variables |
| examples.tf | 7 KB | Usage examples |
| iam.tf | 7 KB | IAM roles and policies |
| security-groups.tf | 5 KB | Security group rules |
| outputs.tf | 5 KB | Output values |
| main.tf | 3 KB | Main cluster resource |

## 🔗 External Resources

### AWS Documentation
- [AWS MSK Developer Guide](https://docs.aws.amazon.com/msk/)
- [MSK IAM Access Control](https://docs.aws.amazon.com/msk/latest/developerguide/iam-access-control.html)
- [MSK Best Practices](https://docs.aws.amazon.com/msk/latest/developerguide/bestpractices.html)

### Terraform Documentation
- [AWS Provider - MSK Cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/msk_cluster)
- [AWS Provider - MSK Configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/msk_configuration)

### Apache Kafka Documentation
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Kafka Security](https://kafka.apache.org/documentation/#security)

## 📝 Quick Reference

### Module Inputs (Key Variables)
```hcl
cluster_name                        # Required: Cluster name
vpc_id                             # Required: VPC ID
subnet_ids                         # Required: Subnet IDs (min 2)
vpc_cidr                           # Required: VPC CIDR
kafka_version                      # Default: "3.5.1"
number_of_broker_nodes             # Default: 3
broker_instance_type               # Default: "kafka.m5.large"
encryption_in_transit_client_broker # Default: "TLS"
enable_iam_auth                    # Default: true
topic_naming_prefix                # Default: "app-"
consumer_group_naming_prefix       # Default: "cg-"
```

### Module Outputs (Key Values)
```hcl
cluster_arn                        # MSK cluster ARN
bootstrap_brokers_sasl_iam         # IAM auth connection string
security_group_id                  # Security group ID
producer_role_arn                  # Producer IAM role ARN
consumer_role_arn                  # Consumer IAM role ARN
topic_naming_prefix                # Topic naming prefix
```

### Common Commands
```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment
terraform plan

# Deploy cluster
terraform apply

# View outputs
terraform output

# Destroy cluster
terraform destroy
```

## 🆘 Getting Help

### Documentation Issues
If you find issues with the documentation:
1. Check if the information is in another document
2. Review the [MODULE_SUMMARY.md](./MODULE_SUMMARY.md) for overview
3. Check [examples.tf](./examples.tf) for practical examples

### Technical Issues
For technical issues:
1. Review [QUICK_START.md](./QUICK_START.md) - Common Issues
2. Check [TOPIC_NAMING_GUIDE.md](./TOPIC_NAMING_GUIDE.md) - Troubleshooting
3. Review CloudWatch logs
4. Check AWS MSK documentation

### Deployment Issues
For deployment issues:
1. Follow [DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md)
2. Verify all prerequisites
3. Check Terraform plan output
4. Review error messages

## 📅 Version Information

- **Terraform Version**: >= 1.0
- **AWS Provider Version**: >= 5.0
- **Default Kafka Version**: 3.5.1
- **Module Version**: 1.0.0

## 🎓 Learning Path

### Beginner
1. [QUICK_START.md](./QUICK_START.md) - Get started
2. [README.md](./README.md) - Understand features
3. [examples.tf](./examples.tf) - See examples

### Intermediate
1. [ARCHITECTURE.md](./ARCHITECTURE.md) - Understand architecture
2. [TOPIC_NAMING_GUIDE.md](./TOPIC_NAMING_GUIDE.md) - Master naming conventions
3. [DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md) - Production deployment

### Advanced
1. [iam.tf](./iam.tf) - Deep dive into IAM policies
2. [security-groups.tf](./security-groups.tf) - Network security details
3. [MODULE_SUMMARY.md](./MODULE_SUMMARY.md) - Complete understanding

---

**Last Updated**: December 2024

**Module Version**: 1.0.0

**Maintained By**: Infrastructure Team
