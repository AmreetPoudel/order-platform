output "execution_role_arn" {
  value = aws_iam_role.ecs_task_execution.arn
}
variable "container_port" {
  type        = number
  description = "Port the application listens on inside the container"
}