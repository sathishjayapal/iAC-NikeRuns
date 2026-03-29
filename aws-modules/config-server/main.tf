data "aws_ami" "this" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# ── VPC ────────────────────────────────────────────────────────────────────────

resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "config-server-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "config-server-igw"
  }
}

resource "aws_subnet" "this" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "config-server-subnet"
  }
}

resource "aws_route_table" "this" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "config-server-rt"
  }
}

resource "aws_route_table_association" "this" {
  subnet_id      = aws_subnet.this.id
  route_table_id = aws_route_table.this.id
}

# ── Security Group ─────────────────────────────────────────────────────────────

resource "aws_security_group" "config_server" {
  name        = "config-server-sg"
  description = "Allow SSH from trusted IP and config server port 8888"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "SSH from trusted IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "Config server port"
    from_port   = 8888
    to_port     = 8888
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "config-server-sg"
  }
}

# ── SSM Parameters (secrets never go into user_data) ──────────────────────────

resource "aws_ssm_parameter" "git_uri" {
  name  = "/config-server/git_uri"
  type  = "String"
  value = var.git_uri
}

resource "aws_ssm_parameter" "encrypt_key" {
  name  = "/config-server/encrypt_key"
  type  = "SecureString"
  value = var.encrypt_key
}

resource "aws_ssm_parameter" "username" {
  name  = "/config-server/username"
  type  = "String"
  value = var.username
}

resource "aws_ssm_parameter" "pass" {
  name  = "/config-server/pass"
  type  = "SecureString"
  value = var.pass
}

# ── IAM Role so EC2 can read SSM parameters ───────────────────────────────────

resource "aws_iam_role" "config_server" {
  name = "config-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "ssm_read" {
  name = "config-server-ssm-read"
  role = aws_iam_role.config_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter", "ssm:GetParameters"]
      Resource = "arn:aws:ssm:*:*:parameter/config-server/*"
    }]
  })
}

resource "aws_iam_instance_profile" "config_server" {
  name = "config-server-profile"
  role = aws_iam_role.config_server.name
}

# ── Key Pair ───────────────────────────────────────────────────────────────────

resource "tls_private_key" "config_server" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "config_server" {
  key_name   = var.key_name
  public_key = tls_private_key.config_server.public_key_openssh
}

resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.config_server.private_key_pem
  filename        = "${path.module}/${var.key_name}.pem"
  file_permission = "0600"
}

# ── EC2 Instance ───────────────────────────────────────────────────────────────

resource "aws_instance" "config_server" {
  ami                    = data.aws_ami.this.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.config_server.key_name
  subnet_id              = aws_subnet.this.id
  vpc_security_group_ids = [aws_security_group.config_server.id]
  iam_instance_profile   = aws_iam_instance_profile.config_server.name

  # Enforce IMDSv2 — prevents SSRF attacks from reading instance metadata
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Encrypt root volume at rest
  root_block_device {
    encrypted = true
  }

  # user_data contains NO secrets — they are fetched from SSM at boot
  user_data = file("${path.module}/scripts/user_data.sh")

  tags = {
    Name = "sathish-config-server"
  }
}

# ── Outputs ────────────────────────────────────────────────────────────────────

output "public_ip" {
  value = aws_instance.config_server.public_ip
}

output "public_dns" {
  value = aws_instance.config_server.public_dns
}

output "health_url" {
  value = "http://${aws_instance.config_server.public_ip}:8888/sathishconfigserver/health"
}

output "ssh_command" {
  value = "ssh -i ${local_sensitive_file.private_key.filename} ec2-user@${aws_instance.config_server.public_ip}"
}
