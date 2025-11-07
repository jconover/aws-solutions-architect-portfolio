# S3 Module Variables

variable "project_name" {
  description = "Project name to be used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "artifacts_retention_days" {
  description = "Number of days to retain build artifacts"
  type        = number
  default     = 30
}

variable "logs_retention_days" {
  description = "Number of days to retain logs before deletion"
  type        = number
  default     = 365
}

variable "backups_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 90
}

variable "create_static_assets_bucket" {
  description = "Create S3 bucket for static assets"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
