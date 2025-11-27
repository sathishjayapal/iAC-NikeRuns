terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

########################################
# Data Sources
########################################

data "aws_subnet" "public_a" {
  id = var.subnet_id_a
}

data "aws_subnet" "public_b" {
  id = var.subnet_id_b
}

data "aws_subnet" "public_c" {
  id = var.subnet_id_c
}

########################################
# Security Group for NodePort Services
########################################

resource "aws_security_group" "nodeport" {
  name        = "${var.cluster_name}-nodeport-sg"
  description = "Security group for Kubernetes NodePort services (30000-32767)"
  vpc_id      = var.vpc_id

  ingress {
    description = "NodePort range for Kubernetes services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = var.nodeport_cidr_blocks
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-nodeport-sg"
    }
  )
}

########################################
# EKS Cluster
########################################

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.service_role_arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids = [
      data.aws_subnet.public_a.id,
      data.aws_subnet.public_b.id,
      data.aws_subnet.public_c.id
    ]
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  tags = merge(
    var.common_tags,
    {
      Name = var.cluster_name
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
  ]
}

########################################
# IAM Role for EKS Cluster (if not using existing)
########################################

resource "aws_iam_role" "cluster" {
  count = var.create_cluster_role ? 1 : 0
  name  = "sathisheksclusterservicerole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  count      = var.create_cluster_role ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster[0].name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceController" {
  count      = var.create_cluster_role ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster[0].name
}

########################################
# OIDC Provider for IRSA
########################################

data "tls_certificate" "cluster" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-oidc-provider"
    }
  )
}

########################################
# Managed Node Group
########################################

resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids = [
    data.aws_subnet.public_a.id,
    data.aws_subnet.public_b.id,
    data.aws_subnet.public_c.id
  ]

  instance_types = [var.node_instance_type]
  capacity_type  = var.node_capacity_type

  scaling_config {
    desired_size = var.node_desired_capacity
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.node_group.id
    version = "$Latest"
  }

  labels = var.node_labels

  tags = merge(
    var.common_tags,
    var.node_group_tags,
    {
      Name                                            = "${var.cluster_name}-${var.node_group_name}"
      "k8s.io/cluster-autoscaler/enabled"             = "true"
      "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]
}

########################################
# IAM Role for Node Group
########################################

resource "aws_iam_role" "node_group" {
  name = "${var.cluster_name}-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

########################################
# Launch Template for Node Group
########################################

resource "aws_launch_template" "node_group" {
  name_prefix = "${var.cluster_name}-${var.node_group_name}-"
  description = "Launch template for ${var.cluster_name} node group with NodePort security group"

  key_name = var.ssh_key_name

  vpc_security_group_ids = [
    aws_security_group.nodeport.id
  ]

  user_data = var.max_pods_per_node != null ? base64encode(templatefile("${path.module}/userdata.sh.tpl", {
    cluster_name      = var.cluster_name
    max_pods_per_node = var.max_pods_per_node
  })) : null

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.common_tags,
      {
        Name = "${var.cluster_name}-${var.node_group_name}-node"
      }
    )
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-${var.node_group_name}-lt"
    }
  )
}
