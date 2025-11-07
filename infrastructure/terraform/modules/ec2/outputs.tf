# EC2 Module Outputs

# Jenkins Outputs
output "jenkins_instance_id" {
  description = "ID of Jenkins instance"
  value       = var.create_jenkins ? aws_instance.jenkins[0].id : ""
}

output "jenkins_private_ip" {
  description = "Private IP of Jenkins instance"
  value       = var.create_jenkins ? aws_instance.jenkins[0].private_ip : ""
}

output "jenkins_public_ip" {
  description = "Public IP of Jenkins instance"
  value       = var.create_jenkins ? aws_instance.jenkins[0].public_ip : ""
}

output "jenkins_elastic_ip" {
  description = "Elastic IP of Jenkins instance"
  value       = var.create_jenkins && var.jenkins_use_elastic_ip ? aws_eip.jenkins[0].public_ip : ""
}

output "jenkins_security_group_id" {
  description = "Security group ID for Jenkins"
  value       = var.create_jenkins ? aws_security_group.jenkins[0].id : ""
}

output "jenkins_url" {
  description = "URL to access Jenkins"
  value       = var.create_jenkins && var.jenkins_use_elastic_ip ? "http://${aws_eip.jenkins[0].public_ip}:8080" : (var.create_jenkins ? "http://${aws_instance.jenkins[0].public_ip}:8080" : "")
}

# Bastion Outputs
output "bastion_instance_id" {
  description = "ID of bastion instance"
  value       = var.create_bastion ? aws_instance.bastion[0].id : ""
}

output "bastion_private_ip" {
  description = "Private IP of bastion instance"
  value       = var.create_bastion ? aws_instance.bastion[0].private_ip : ""
}

output "bastion_public_ip" {
  description = "Public IP of bastion instance"
  value       = var.create_bastion ? aws_instance.bastion[0].public_ip : ""
}

output "bastion_elastic_ip" {
  description = "Elastic IP of bastion instance"
  value       = var.create_bastion ? aws_eip.bastion[0].public_ip : ""
}

output "bastion_security_group_id" {
  description = "Security group ID for bastion"
  value       = var.create_bastion ? aws_security_group.bastion[0].id : ""
}

# General Outputs
output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for EC2 instances"
  value       = var.create_jenkins || var.create_bastion ? aws_cloudwatch_log_group.ec2[0].name : ""
}
