# S3 Module Outputs

output "artifacts_bucket_id" {
  description = "ID of the artifacts bucket"
  value       = aws_s3_bucket.artifacts.id
}

output "artifacts_bucket_arn" {
  description = "ARN of the artifacts bucket"
  value       = aws_s3_bucket.artifacts.arn
}

output "logs_bucket_id" {
  description = "ID of the logs bucket"
  value       = aws_s3_bucket.logs.id
}

output "logs_bucket_arn" {
  description = "ARN of the logs bucket"
  value       = aws_s3_bucket.logs.arn
}

output "backups_bucket_id" {
  description = "ID of the backups bucket"
  value       = aws_s3_bucket.backups.id
}

output "backups_bucket_arn" {
  description = "ARN of the backups bucket"
  value       = aws_s3_bucket.backups.arn
}

output "static_assets_bucket_id" {
  description = "ID of the static assets bucket"
  value       = var.create_static_assets_bucket ? aws_s3_bucket.static_assets[0].id : ""
}

output "static_assets_bucket_arn" {
  description = "ARN of the static assets bucket"
  value       = var.create_static_assets_bucket ? aws_s3_bucket.static_assets[0].arn : ""
}
