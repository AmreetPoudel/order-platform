# ==============================================================================
# modules/ECS/task_sg.tf
#
# Security Group for ECS Fargate Tasks (Frontend, API, Worker).
# Allows inbound traffic ONLY from the Application Load Balancer (ALB).
# ==============================================================================

resource "aws_security_group" "ecs_task_sg" {
  name        = "order-platform-ecs-task-sg"
  description = "Controls inbound traffic to ECS Fargate tasks from ALB"
  vpc_id      = var.vpc_id

  # ----------------------------------------------------------------------------
  # 1. Allow Frontend Inbound (Port 80) from ALB
  # ----------------------------------------------------------------------------
  ingress {
    description     = "Allow HTTP traffic from ALB to Frontend task"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  # ----------------------------------------------------------------------------
  # 2. Allow API Inbound (Port 4000) from ALB
  # ----------------------------------------------------------------------------
  ingress {
    description     = "Allow HTTP traffic from ALB to API backend task"
    from_port       = 4000
    to_port         = 4000
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  # ----------------------------------------------------------------------------
  # 3. Egress (Outbound)
  # Allows tasks to reach NAT Gateway (Docker Hub image pulls, SSM),
  # and communicate with the Stateful EC2 host (Postgres, Redis, RabbitMQ)
  # ----------------------------------------------------------------------------
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "order-platform-ecs-task-sg"
  }
}