# EC2 Module
# Creates Jenkins server and optional Bastion host

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Jenkins Security Group
resource "aws_security_group" "jenkins" {
  count       = var.create_jenkins ? 1 : 0
  name        = "${var.project_name}-jenkins-sg"
  description = "Security group for Jenkins server"
  vpc_id      = var.vpc_id

  # SSH access
  ingress {
    description = "SSH from allowed CIDRs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # Jenkins web interface
  ingress {
    description = "Jenkins web UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_jenkins_cidrs
  }

  # Jenkins agent port
  ingress {
    description = "Jenkins agent communication"
    from_port   = 50000
    to_port     = 50000
    protocol    = "tcp"
    cidr_blocks = var.allowed_jenkins_cidrs
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-jenkins-sg"
    }
  )
}

# Jenkins Server
resource "aws_instance" "jenkins" {
  count                  = var.create_jenkins ? 1 : 0
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.jenkins_instance_type
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.jenkins[0].id]
  iam_instance_profile   = var.jenkins_iam_instance_profile
  key_name               = var.key_name

  root_block_device {
    volume_size           = var.jenkins_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = base64encode(templatefile("${path.module}/user-data-jenkins.sh", {
    project_name = var.project_name
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-jenkins-server"
      Type = "Jenkins"
    }
  )
}

# Elastic IP for Jenkins (optional but recommended)
resource "aws_eip" "jenkins" {
  count    = var.create_jenkins && var.jenkins_use_elastic_ip ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.jenkins[0].id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-jenkins-eip"
    }
  )
}

# Bastion Host Security Group
resource "aws_security_group" "bastion" {
  count       = var.create_bastion ? 1 : 0
  name        = "${var.project_name}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = var.vpc_id

  # SSH access from allowed CIDRs
  ingress {
    description = "SSH from allowed CIDRs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-bastion-sg"
    }
  )
}

# Bastion Host
resource "aws_instance" "bastion" {
  count                  = var.create_bastion ? 1 : 0
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.bastion_instance_type
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.bastion[0].id]
  key_name               = var.key_name

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = base64encode(templatefile("${path.module}/user-data-bastion.sh", {
    project_name = var.project_name
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-bastion-host"
      Type = "Bastion"
    }
  )
}

# Elastic IP for Bastion
resource "aws_eip" "bastion" {
  count    = var.create_bastion ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.bastion[0].id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-bastion-eip"
    }
  )
}

# CloudWatch Log Group for EC2 logs
resource "aws_cloudwatch_log_group" "ec2" {
  count             = var.create_jenkins || var.create_bastion ? 1 : 0
  name              = "/aws/ec2/${var.project_name}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-ec2-logs"
    }
  )
}
