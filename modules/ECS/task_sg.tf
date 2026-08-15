resource "aws_security_group" "ecs_task_sg" {
  name        = "order-platform-ecs-task-sg"
  description = "Allow inbound traffic to ECS tasks only from ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow traffic from ALB on container port"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  egress {
    description = "Allow all outbound (needed for NAT-routed internet access, e.g. pulling image, calling external APIs)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "order-platform-ecs-task-sg"
  }
}