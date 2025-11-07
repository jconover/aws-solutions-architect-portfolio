# IAM Module Outputs

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_execution_role_name" {
  description = "Name of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.name
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task.arn
}

output "ecs_task_role_name" {
  description = "Name of the ECS task role"
  value       = aws_iam_role.ecs_task.name
}

output "jenkins_role_arn" {
  description = "ARN of the Jenkins IAM role"
  value       = aws_iam_role.jenkins.arn
}

output "jenkins_role_name" {
  description = "Name of the Jenkins IAM role"
  value       = aws_iam_role.jenkins.name
}

output "jenkins_instance_profile_name" {
  description = "Name of the Jenkins instance profile"
  value       = aws_iam_instance_profile.jenkins.name
}

output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster role"
  value       = var.create_eks_roles ? aws_iam_role.eks_cluster[0].arn : ""
}

output "eks_node_group_role_arn" {
  description = "ARN of the EKS node group role"
  value       = var.create_eks_roles ? aws_iam_role.eks_node_group[0].arn : ""
}
