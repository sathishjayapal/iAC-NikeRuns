# Security Group for MSK Cluster - Only necessary ports
resource "aws_security_group" "msk" {
  name        = "${var.cluster_name}-msk-sg"
  description = "Security group for MSK cluster with minimal required ports"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-msk-sg"
    }
  )
}

# Ingress rule for Kafka plaintext (only if not using TLS)
resource "aws_vpc_security_group_ingress_rule" "kafka_plaintext" {
  count             = var.encryption_in_transit_client_broker == "PLAINTEXT" ? 1 : 0
  security_group_id = aws_security_group.msk.id
  description       = "Kafka plaintext communication"
  
  from_port   = 9092
  to_port     = 9092
  ip_protocol = "tcp"
  cidr_ipv4   = var.allowed_cidr_blocks != null ? var.allowed_cidr_blocks : var.vpc_cidr
}

# Ingress rule for Kafka TLS
resource "aws_vpc_security_group_ingress_rule" "kafka_tls" {
  count             = var.encryption_in_transit_client_broker == "TLS" || var.encryption_in_transit_client_broker == "TLS_PLAINTEXT" ? 1 : 0
  security_group_id = aws_security_group.msk.id
  description       = "Kafka TLS communication"
  
  from_port   = 9094
  to_port     = 9094
  ip_protocol = "tcp"
  cidr_ipv4   = var.allowed_cidr_blocks != null ? var.allowed_cidr_blocks : var.vpc_cidr
}

# Ingress rule for Kafka SASL/SCRAM
resource "aws_vpc_security_group_ingress_rule" "kafka_sasl_scram" {
  count             = var.enable_scram_auth ? 1 : 0
  security_group_id = aws_security_group.msk.id
  description       = "Kafka SASL/SCRAM authentication"
  
  from_port   = 9096
  to_port     = 9096
  ip_protocol = "tcp"
  cidr_ipv4   = var.allowed_cidr_blocks != null ? var.allowed_cidr_blocks : var.vpc_cidr
}

# Ingress rule for Kafka IAM authentication
resource "aws_vpc_security_group_ingress_rule" "kafka_iam" {
  count             = var.enable_iam_auth ? 1 : 0
  security_group_id = aws_security_group.msk.id
  description       = "Kafka IAM authentication"
  
  from_port   = 9098
  to_port     = 9098
  ip_protocol = "tcp"
  cidr_ipv4   = var.allowed_cidr_blocks != null ? var.allowed_cidr_blocks : var.vpc_cidr
}

# Ingress rule for Zookeeper (only for internal cluster communication)
resource "aws_vpc_security_group_ingress_rule" "zookeeper" {
  security_group_id            = aws_security_group.msk.id
  description                  = "Zookeeper internal cluster communication"
  referenced_security_group_id = aws_security_group.msk.id
  
  from_port   = 2181
  to_port     = 2181
  ip_protocol = "tcp"
}

# Ingress rule for JMX Exporter (monitoring)
resource "aws_vpc_security_group_ingress_rule" "jmx_exporter" {
  count             = var.enable_jmx_exporter ? 1 : 0
  security_group_id = aws_security_group.msk.id
  description       = "JMX Exporter for monitoring"
  
  from_port   = 11001
  to_port     = 11001
  ip_protocol = "tcp"
  cidr_ipv4   = var.allowed_cidr_blocks != null ? var.allowed_cidr_blocks : var.vpc_cidr
}

# Ingress rule for Node Exporter (monitoring)
resource "aws_vpc_security_group_ingress_rule" "node_exporter" {
  count             = var.enable_node_exporter ? 1 : 0
  security_group_id = aws_security_group.msk.id
  description       = "Node Exporter for monitoring"
  
  from_port   = 11002
  to_port     = 11002
  ip_protocol = "tcp"
  cidr_ipv4   = var.allowed_cidr_blocks != null ? var.allowed_cidr_blocks : var.vpc_cidr
}

# Egress rule - Allow all outbound traffic (required for cluster operations)
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.msk.id
  description       = "Allow all outbound traffic"
  
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

# Optional: Security group for client applications
resource "aws_security_group" "msk_clients" {
  count       = var.create_client_security_group ? 1 : 0
  name        = "${var.cluster_name}-msk-clients-sg"
  description = "Security group for MSK client applications"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-msk-clients-sg"
    }
  )
}

# Allow clients to communicate with MSK cluster
resource "aws_vpc_security_group_ingress_rule" "msk_from_clients" {
  count                        = var.create_client_security_group ? 1 : 0
  security_group_id            = aws_security_group.msk.id
  description                  = "Allow traffic from client security group"
  referenced_security_group_id = aws_security_group.msk_clients[0].id
  
  from_port   = 0
  to_port     = 65535
  ip_protocol = "tcp"
}

# Allow clients to reach MSK cluster
resource "aws_vpc_security_group_egress_rule" "clients_to_msk" {
  count                        = var.create_client_security_group ? 1 : 0
  security_group_id            = aws_security_group.msk_clients[0].id
  description                  = "Allow traffic to MSK cluster"
  referenced_security_group_id = aws_security_group.msk.id
  
  ip_protocol = "-1"
}
