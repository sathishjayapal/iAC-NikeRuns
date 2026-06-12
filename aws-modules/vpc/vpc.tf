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
# Public Route Table
# Routes 0.0.0.0/0 → Internet Gateway
# Used by: SSM relay EC2, load balancers
########################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-public-rt"
    Network = "Public"
  }
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

########################################
# Private Route Table
# No route to the internet.
# Used by: Aurora database
# Resources here are only reachable from
# inside the VPC — not from the internet.
########################################

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name    = "${var.name_prefix}-private-rt"
    Network = "Private"
  }
}

########################################
# Public Subnets (internet-reachable)
########################################

resource "aws_subnet" "subnet01" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnet01_cidr
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.name_prefix}-public-01"
    "kubernetes.io/role/elb" = "1"
    Tier = "Public"
  }
}

resource "aws_subnet" "subnet02" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnet02_cidr
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.name_prefix}-public-02"
    "kubernetes.io/role/elb" = "1"
    Tier = "Public"
  }
}

resource "aws_subnet" "subnet03" {
  count                   = local.has_more_than_2_azs ? 1 : 0
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnet03_cidr
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[2]

  tags = {
    Name = "${var.name_prefix}-public-03"
    "kubernetes.io/role/elb" = "1"
    Tier = "Public"
  }
}

########################################
# Private Subnets (no internet route)
# Aurora lives here. Not reachable from
# the internet — only from inside the VPC.
########################################

resource "aws_subnet" "private01" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_subnet01_cidr
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.name_prefix}-private-01"
    Tier = "Private"
  }
}

resource "aws_subnet" "private02" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_subnet02_cidr
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.name_prefix}-private-02"
    Tier = "Private"
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

resource "aws_route_table_association" "private01" {
  subnet_id      = aws_subnet.private01.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private02" {
  subnet_id      = aws_subnet.private02.id
  route_table_id = aws_route_table.private.id
}

########################################
# Security Group for EKS Control Plane
########################################

resource "aws_security_group" "control_plane" {
  name        = "${var.name_prefix}-control-plane-sg"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-control-plane-sg"
  }
}
