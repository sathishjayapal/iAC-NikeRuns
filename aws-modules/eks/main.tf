terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "kubernetes" {
  host                   = aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      aws_eks_cluster.this.name,
      "--region",
      var.region
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        aws_eks_cluster.this.name,
        "--region",
        var.region
      ]
    }
  }
}

########################################
# Data Sources
########################################

data "aws_subnet" "public_a" {
  id = "subnet-0ce25994763da6aae"
}

data "aws_subnet" "public_b" {
  id = "subnet-0725627f1a0851e25"
}

data "aws_subnet" "public_c" {
  id = "subnet-01a73f2ece83afd8d"
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
  vpc_id      = "vpc-0a1753e65db583cd6"

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
      Name = "${var.cluster_name}-nodeport-sg"
    }
  )
}

########################################
# EKS Cluster
########################################

resource "aws_eks_cluster" "this" {
  name     = "sathish-eks-cluster-01"
  role_arn = "arn:aws:iam::381636780001:role/sathisheksclusterservicerole"
  version  = "1.28"

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
      Name = var.cluster_name
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
  node_group_name = "ng-1-workers"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids = [
    data.aws_subnet.public_a.id,
    data.aws_subnet.public_b.id,
    data.aws_subnet.public_c.id
  ]

  instance_types = [var.node_instance_type]
  capacity_type  = var.node_capacity_type

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 4
  }

  update_config {
    max_unavailable = 1
  }

  # Use launch template for SSH access (matches eksctl behavior)
  launch_template {
    id      = aws_launch_template.node_group.id
    version = "$Latest"
  }

  remote_access {
    ec2_ssh_key = "foreksworkloads"
  }

  labels = {
    role = "workers"
  }

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
# EKS Addons (matching eksctl defaults)
########################################

resource "aws_iam_role" "node_group" {
  name = "${var.cluster_name}-node-group-role"

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

########################################
# AWS Load Balancer Controller
########################################

# Get AWS account ID and OIDC provider URL
data "aws_caller_identity" "current" {}

locals {
  oidc_provider_url = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

# IAM Policy for AWS Load Balancer Controller
resource "aws_iam_policy" "aws_load_balancer_controller" {
  count       = var.enable_aws_load_balancer_controller ? 1 : 0
  name        = "${var.cluster_name}-AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/aws-load-balancer-controller-iam-policy.json")

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-aws-load-balancer-controller-policy"
    }
  )
}

# IAM Role for AWS Load Balancer Controller (IRSA)
resource "aws_iam_role" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0
  name  = "${var.cluster_name}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.enable_oidc ? aws_iam_openid_connect_provider.cluster[0].arn : ""
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
            "${local.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name = "${var.cluster_name}-aws-load-balancer-controller-role"
    }
  )
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  count      = var.enable_aws_load_balancer_controller ? 1 : 0
  policy_arn = aws_iam_policy.aws_load_balancer_controller[0].arn
  role       = aws_iam_role.aws_load_balancer_controller[0].name
}

# Kubernetes Service Account for AWS Load Balancer Controller
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller[0].arn
    }
  }

  depends_on = [
    aws_eks_cluster.this,
    aws_eks_node_group.workers
  ]
}

# Deploy AWS Load Balancer Controller using Helm
resource "helm_release" "aws_load_balancer_controller" {
  count      = var.enable_aws_load_balancer_controller ? 1 : 0
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.aws_load_balancer_controller_version

  set {
    name  = "clusterName"
    value = aws_eks_cluster.this.name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  depends_on = [
    kubernetes_service_account.aws_load_balancer_controller,
    aws_eks_node_group.workers
  ]
}
