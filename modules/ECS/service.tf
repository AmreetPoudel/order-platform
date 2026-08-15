# ==============================================================================
# modules/ECS/service.tf
#
# Creates the 3 ECS Fargate Services:
#   1. frontend : Attached to ALB Frontend Target Group (Port 80)
#   2. api      : Attached to ALB API Target Group (Port 4000)
#   3. worker   : Standalone background service (No ALB)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Frontend Service (Port 80)
# ------------------------------------------------------------------------------
resource "aws_ecs_service" "frontend" {
  name            = "order-platform-frontend-service"
  cluster         = aws_ecs_cluster.order_platform_ecs_cluster.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_task_sg.id]
    assign_public_ip = false # Safe inside private subnets, egress via NAT
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name   = "frontend"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Name = "order-platform-frontend-service"
  }
}

# ------------------------------------------------------------------------------
# 2. API Backend Service (Port 4000)
# ------------------------------------------------------------------------------
resource "aws_ecs_service" "api" {
  name            = "order-platform-api-service"
  cluster         = aws_ecs_cluster.order_platform_ecs_cluster.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_task_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 4000
  }

  depends_on = [aws_lb_listener_rule.api_routing]

  tags = {
    Name = "order-platform-api-service"
  }
}

# ------------------------------------------------------------------------------
# 3. Worker Service (Background Queue Consumer)
# ------------------------------------------------------------------------------
resource "aws_ecs_service" "worker" {
  name            = "order-platform-worker-service"
  cluster         = aws_ecs_cluster.order_platform_ecs_cluster.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_task_sg.id]
    assign_public_ip = false
  }

  # No load_balancer block: Worker does not receive inbound HTTP requests

  tags = {
    Name = "order-platform-worker-service"
  }
}