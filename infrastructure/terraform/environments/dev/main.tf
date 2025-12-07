# Main Terraform Configuration - Development Environment

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Optional: Configure remote backend for state management
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "aws-cloudforge/dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "aws-cloudforge"
    }
  }
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  data_subnet_cidrs    = var.data_subnet_cidrs

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
  enable_s3_endpoint = var.enable_s3_endpoint
  enable_flow_logs   = false

  aws_region  = var.aws_region
  common_tags = local.common_tags
}

# S3 Module
module "s3" {
  source = "../../modules/s3"

  project_name = var.project_name
  environment  = var.environment

  artifacts_retention_days    = var.artifacts_retention_days
  logs_retention_days         = var.logs_retention_days
  backups_retention_days      = var.backups_retention_days
  create_static_assets_bucket = true

  common_tags = local.common_tags
}

# IAM Module
module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  aws_region   = var.aws_region

  artifacts_bucket_arn = module.s3.artifacts_bucket_arn
  logs_bucket_arn      = module.s3.logs_bucket_arn
  backups_bucket_arn   = module.s3.backups_bucket_arn

  create_eks_roles = var.enable_eks

  common_tags = local.common_tags
}

# ECS Module
module "ecs" {
  source = "../../modules/ecs"

  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id

  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  enable_container_insights  = var.enable_container_insights
  enable_fargate_spot        = var.enable_fargate_spot
  fargate_spot_weight        = var.fargate_spot_weight
  enable_deletion_protection = false
  log_retention_days         = 7

  common_tags = local.common_tags
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS database"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "PostgreSQL from ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.ecs.ecs_tasks_security_group_id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-rds-sg"
    }
  )
}

# RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = module.vpc.data_subnet_ids

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-db-subnet-group"
    }
  )
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-db"

  engine         = "postgres"
  engine_version = "17.4"
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az                = false # Enable for production
  publicly_accessible     = false
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  skip_final_snapshot       = true
  final_snapshot_identifier = "${var.project_name}-db-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-db"
    }
  )
}

# EC2 Module (Optional - uncomment to deploy Jenkins and/or Bastion)
# module "ec2" {
#   source = "../../modules/ec2"
#
#   project_name = var.project_name
#   vpc_id       = module.vpc.vpc_id
#
#   public_subnet_ids = module.vpc.public_subnet_ids
#   key_name          = var.ssh_key_name  # Add this variable to variables.tf
#
#   # Jenkins Configuration
#   create_jenkins                = true
#   jenkins_instance_type         = "t3.medium"
#   jenkins_volume_size           = 50
#   jenkins_use_elastic_ip        = true
#   jenkins_iam_instance_profile  = module.iam.jenkins_instance_profile_name
#   allowed_jenkins_cidrs         = ["0.0.0.0/0"]  # IMPORTANT: Restrict to your IP in production
#
#   # Bastion Configuration
#   create_bastion        = false  # Set to true if you need bastion access
#   bastion_instance_type = "t3.micro"
#
#   # Security - IMPORTANT: Restrict SSH to your IP
#   allowed_ssh_cidrs = ["0.0.0.0/0"]  # Change to ["YOUR_IP/32"]
#
#   common_tags = local.common_tags
# }

# Output the important values
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.ecs.alb_dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "frontend_ecr_url" {
  description = "Frontend ECR repository URL"
  value       = module.ecs.frontend_ecr_repository_url
}

output "backend_ecr_url" {
  description = "Backend ECR repository URL"
  value       = module.ecs.backend_ecr_repository_url
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "artifacts_bucket" {
  description = "Artifacts S3 bucket name"
  value       = module.s3.artifacts_bucket_id
}

output "jenkins_instance_profile" {
  description = "Jenkins instance profile name"
  value       = module.iam.jenkins_instance_profile_name
}

# EC2 Outputs (uncomment when EC2 module is enabled)
# output "jenkins_url" {
#   description = "Jenkins web interface URL"
#   value       = module.ec2.jenkins_url
# }
#
# output "jenkins_ip" {
#   description = "Jenkins server IP address"
#   value       = module.ec2.jenkins_elastic_ip
# }
#
# output "bastion_ip" {
#   description = "Bastion host IP address"
#   value       = module.ec2.bastion_elastic_ip
# }
