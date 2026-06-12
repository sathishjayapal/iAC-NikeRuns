terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_vpc" "this" {
  id = var.vpc_id
}

data "aws_subnet" "selected" {
  for_each = toset(var.subnet_ids)
  id       = each.value
}

locals {
  azs = distinct([for s in data.aws_subnet.selected : s.availability_zone])

  # Fargate must attach to private subnets. When create_private_subnets=true,
  # we use the subnets created in private-subnets.tf; otherwise we fall back
  # to the caller-supplied subnet_ids (which must already be private).
  fargate_subnet_ids = var.create_private_subnets ? aws_subnet.private[*].id : var.subnet_ids
}

resource "null_resource" "validate_az_count" {
  lifecycle {
    precondition {
      condition     = length(local.azs) >= 2
      error_message = "subnet_ids must cover at least 2 distinct availability zones (Fargate requirement). Currently covering: ${jsonencode(local.azs)}"
    }
  }
}

resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    # The EKS control plane is fine on public subnets; only Fargate profiles
    # need private subnets. We give the cluster both when we have them, to
    # support load balancers + private workloads in future iterations.
    subnet_ids              = var.create_private_subnets ? concat(var.subnet_ids, aws_subnet.private[*].id) : var.subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = var.public_access_cidrs
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
  ]
}

data "tls_certificate" "cluster" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_role" "fargate_pod_execution" {
  name = "${var.cluster_name}-fargate-pod-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
      Action = "sts:AssumeRole"
      Condition = {
        ArnLike = {
          "aws:SourceArn" = "arn:aws:eks:${var.region}:*:fargateprofile/${var.cluster_name}/*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "fargate_AmazonEKSFargatePodExecutionRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.fargate_pod_execution.name
}

resource "aws_eks_fargate_profile" "system" {
  cluster_name           = aws_eks_cluster.this.name
  fargate_profile_name   = "fp-system"
  pod_execution_role_arn = aws_iam_role.fargate_pod_execution.arn
  subnet_ids             = local.fargate_subnet_ids

  selector {
    namespace = "kube-system"
  }

  depends_on = [
    aws_iam_role_policy_attachment.fargate_AmazonEKSFargatePodExecutionRolePolicy,
    aws_route_table_association.private,
  ]
}

resource "aws_eks_fargate_profile" "microservices" {
  cluster_name           = aws_eks_cluster.this.name
  fargate_profile_name   = "fp-microservices"
  pod_execution_role_arn = aws_iam_role.fargate_pod_execution.arn
  subnet_ids             = local.fargate_subnet_ids

  selector {
    namespace = "microservices"
  }

  depends_on = [
    aws_iam_role_policy_attachment.fargate_AmazonEKSFargatePodExecutionRolePolicy,
    aws_route_table_association.private,
  ]
}
