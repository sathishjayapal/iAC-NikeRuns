# Opt-in: creates 2 private subnets + 1 NAT GW + 1 route table inside the
# existing sandbox VPC so Fargate profiles can attach to subnets that don't
# route directly to an IGW (AWS hard requirement for Fargate).
#
# Enabled by setting `create_private_subnets = true` in terraform.tfvars.
# When disabled (default), this file is a no-op.

locals {
  create_private = var.create_private_subnets

  # Use the same AZs the caller already provided via the public subnet IDs.
  # `local.azs` is defined in main.tf.
  selected_azs = slice(local.azs, 0, 2)
}

resource "aws_subnet" "private" {
  count                   = local.create_private ? 2 : 0
  vpc_id                  = var.vpc_id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = local.selected_azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name                                        = "${var.cluster_name}-private-${local.selected_azs[count.index]}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_eip" "nat" {
  count  = local.create_private ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "${var.cluster_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "this" {
  count         = local.create_private ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  # NAT GW lives in a public subnet (the first one the caller passed in).
  subnet_id = var.subnet_ids[0]

  tags = {
    Name = "${var.cluster_name}-nat"
  }
}

resource "aws_route_table" "private" {
  count  = local.create_private ? 1 : 0
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[0].id
  }

  tags = {
    Name = "${var.cluster_name}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = local.create_private ? 2 : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}
