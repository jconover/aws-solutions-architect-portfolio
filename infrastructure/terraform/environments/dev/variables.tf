# Development Environment Variables

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "cloudforge"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]
}

variable "data_subnet_cidrs" {
  description = "Data subnet CIDR blocks"
  type        = list(string)
  default     = ["10.20.20.0/24", "10.20.21.0/24"]
}

# Network Configuration
variable "enable_nat_gateway" {
  description = "Enable NAT gateway"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway (cost optimization for dev)"
  type        = bool
  default     = true
}

variable "enable_s3_endpoint" {
  description = "Enable S3 VPC endpoint"
  type        = bool
  default     = true
}

# ECS Configuration
variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

variable "enable_fargate_spot" {
  description = "Enable Fargate Spot"
  type        = bool
  default     = true
}

variable "fargate_spot_weight" {
  description = "Weight for Fargate Spot capacity"
  type        = number
  default     = 50
}

# S3 Configuration
variable "artifacts_retention_days" {
  description = "Artifacts retention in days"
  type        = number
  default     = 30
}

variable "logs_retention_days" {
  description = "Logs retention in days"
  type        = number
  default     = 90
}

variable "backups_retention_days" {
  description = "Backups retention in days"
  type        = number
  default     = 30
}

# Database Configuration
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "dbadmin"
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  # Set this via environment variable: TF_VAR_db_password
  # or use AWS Secrets Manager in production
}

# EKS Configuration
variable "enable_eks" {
  description = "Enable EKS resources"
  type        = bool
  default     = false # Set to true when ready to deploy EKS
}
