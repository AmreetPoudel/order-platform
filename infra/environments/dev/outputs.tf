# ==============================================================================
# infra/environments/dev/outputs.tf
#
# Key infrastructure endpoints displayed after running `terraform apply`
# ==============================================================================

output "alb_dns_name" {
  description = "Public URL to access the Frontend React App and API in your web browser"
  value       = "http://${module.ALB.order_platform_dns_name}"
}

output "stateful_ec2_private_ip" {
  description = "Private IP of the EC2 instance hosting PostgreSQL, Redis, and RabbitMQ"
  value       = module.stateful_ec2.private_ip
}

output "ecs_cluster_name" {
  description = "Name of the ECS Fargate Cluster"
  value       = module.ecs.cluster_name
}

output "api_service_name" {
  description = "Name of the API Backend ECS Fargate Service"
  value       = module.ecs.api_service_name
}

output "frontend_service_name" {
  description = "Name of the Frontend Web ECS Fargate Service"
  value       = module.ecs.frontend_service_name
}

output "worker_service_name" {
  description = "Name of the Worker Consumer ECS Fargate Service"
  value       = module.ecs.worker_service_name
}
