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
# Security Groups (matching eksctl)
########################################

resource "aws_security_group" "control_plane" {
  name_prefix = "${var.cluster_name}-ControlPlaneSecurityGroup-"
  description = "Communication between the control plane and worker nodegroups"
  vpc_id      = var.vpc_id

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
      Name = "${var.cluster_name}-ControlPlaneSecurityGroup"
    }
  )
}

resource "aws_security_group" "nodeport" {
  name        = "dotsky-nodeport-sg"
  description = "Security group for Kubernetes NodePort services (30000-32767)"
  vpc_id      = var.vpc_id

  ingress {
    description = "NodePort range for Kubernetes services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
      Name = "dotsky-nodeport-sg"
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
    endpoint_private_access = false
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.control_plane.id]
  }

  tags = var.common_tags
}

########################################
# OIDC Provider for IRSA
########################################

data "tls_certificate" "cluster" {
  count = var.enable_oidc ? 1 : 0
  url   = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  count           = var.enable_oidc ? 1 : 0
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster[0].certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-oidc-provider"
    }
  )
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
  description = "Launch template for ${var.cluster_name} node group"

  key_name = var.ssh_key_name

  vpc_security_group_ids = [
    aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
    aws_security_group.nodeport.id
  ]

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 80
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "disabled"
  }

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

  scaling_config {
    desired_size = var.node_desired_capacity
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  # Use launch template for SSH access (matches eksctl behavior)
  launch_template {
    id      = aws_launch_template.node_group.id
    version = "$Latest"
  }

  labels = var.node_labels

  tags = merge(
    var.common_tags,
    var.node_group_tags
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]
}

########################################
# EKS Addons (matching eksctl defaults)
########################################

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "vpc-cni"

  depends_on = [aws_eks_cluster.this]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "kube-proxy"

  depends_on = [aws_eks_cluster.this]
}

# Note: coredns is NOT managed as an addon
# AWS EKS has a bug where coredns addon gets stuck in CREATING status
# The coredns pods run fine without addon management
# EKS automatically deploys coredns when the cluster is created

# Note: metrics-server is NOT included
# eksctl installs it but it fails (CREATE_FAILED status in eks-cluster-01)
# The cluster works fine without it - it's optional for basic operations
