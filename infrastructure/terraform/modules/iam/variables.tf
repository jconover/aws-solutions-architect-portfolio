# IAM Module Variables

variable "project_name" {
  description = "Project name to be used for resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "artifacts_bucket_arn" {
  description = "ARN of the artifacts S3 bucket"
  type        = string
}

variable "logs_bucket_arn" {
  description = "ARN of the logs S3 bucket"
  type        = string
}

variable "backups_bucket_arn" {
  description = "ARN of the backups S3 bucket"
  type        = string
}

variable "create_eks_roles" {
  description = "Create IAM roles for EKS"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
