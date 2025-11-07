# EC2 Module Variables

variable "project_name" {
  description = "Project name to be used for resource naming"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "key_name" {
  description = "SSH key pair name for EC2 instances"
  type        = string
}

# Jenkins Configuration
variable "create_jenkins" {
  description = "Create Jenkins server"
  type        = bool
  default     = true
}

variable "jenkins_instance_type" {
  description = "Instance type for Jenkins server"
  type        = string
  default     = "t3.medium"
}

variable "jenkins_volume_size" {
  description = "Root volume size for Jenkins server (GB)"
  type        = number
  default     = 50
}

variable "jenkins_iam_instance_profile" {
  description = "IAM instance profile for Jenkins"
  type        = string
}

variable "jenkins_use_elastic_ip" {
  description = "Allocate and associate Elastic IP to Jenkins"
  type        = bool
  default     = true
}

variable "allowed_jenkins_cidrs" {
  description = "CIDR blocks allowed to access Jenkins web interface"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Bastion Configuration
variable "create_bastion" {
  description = "Create bastion host"
  type        = bool
  default     = false
}

variable "bastion_instance_type" {
  description = "Instance type for bastion host"
  type        = string
  default     = "t3.micro"
}

# Security
variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Logging
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
