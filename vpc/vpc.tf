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
# Data & Locals
########################################

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # True when the region has 3 or more AZs
  has_more_than_2_azs = length(data.aws_availability_zones.available.names) > 2
}

########################################
# VPC and Internet Gateway
########################################

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-VPC"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

########################################
# Public Route Table and Default Route
########################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name    = "Public Subnets"
    Network = "Public"
  }
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

########################################
# Public Subnets
########################################

resource "aws_subnet" "subnet01" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnet01_cidr
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name                     = "${var.name_prefix}-Subnet01"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "subnet02" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnet02_cidr
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[1]

  tags = {
    Name                     = "${var.name_prefix}-Subnet02"
    "kubernetes.io/role/elb" = "1"
  }
}

# Subnet 03 is created only if the region has >= 3 AZs
resource "aws_subnet" "subnet03" {
  count                   = local.has_more_than_2_azs ? 1 : 0
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnet03_cidr
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[2]

  tags = {
    Name                     = "${var.name_prefix}-Subnet03"
    "kubernetes.io/role/elb" = "1"
  }
}

########################################
# Route Table Associations
########################################

resource "aws_route_table_association" "subnet01" {
  subnet_id      = aws_subnet.subnet01.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "subnet02" {
  subnet_id      = aws_subnet.subnet02.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "subnet03" {
  count          = local.has_more_than_2_azs ? 1 : 0
  subnet_id      = aws_subnet.subnet03[0].id
  route_table_id = aws_route_table.public.id
}

########################################
# Security Group for EKS Control Plane
########################################

resource "aws_security_group" "control_plane" {
  name        = "${var.name_prefix}-control-plane-sg"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.this.id

  # Add ingress/egress rules as needed for your EKS setup

  tags = {
    Name = "${var.name_prefix}-control-plane-sg"
  }
}