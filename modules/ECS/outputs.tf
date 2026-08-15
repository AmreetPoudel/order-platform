# ==============================================================================
# modules/ECS/outputs.tf
#
# Outputs from the ECS Fargate module
# ==============================================================================

output "cluster_id" {
  description = "The ID of the ECS Cluster"
  value       = aws_ecs_cluster.order_platform_ecs_cluster.id
}

output "cluster_name" {
  description = "The Name of the ECS Cluster"
  value       = aws_ecs_cluster.order_platform_ecs_cluster.name
}

output "execution_role_arn" {
  description = "The ARN of the ECS Task Execution IAM Role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_sg_id" {
  description = "The Security Group ID attached to the ECS Fargate tasks"
  value       = aws_security_group.ecs_task_sg.id
}

output "api_service_name" {
  description = "Name of the API ECS Service"
  value       = aws_ecs_service.api.name
}

output "frontend_service_name" {
  description = "Name of the Frontend ECS Service"
  value       = aws_ecs_service.frontend.name
}

output "worker_service_name" {
  description = "Name of the Worker ECS Service"
  value       = aws_ecs_service.worker.name
}