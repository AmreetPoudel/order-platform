# ==============================================================================
# modules/SG/main.tf
# 
# Purpose: Security Groups for the Application Load Balancer (ALB).
# ==============================================================================

resource "aws_security_group" "order_platform_alb_sg" {
  name        = "order_platform_alb_sg"
  description = "Public-facing security group for ALB (allows HTTP/HTTPS from Internet)"
  vpc_id      = var.order_platform_vpc_id

  # Inbound HTTP (Port 80) from anywhere in the world
  ingress {
    description = "Allow HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound HTTPS (Port 443) from anywhere in the world
  ingress {
    description = "Allow HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound Egress: Crucial for ALB to forward traffic to ECS target groups in the VPC
  egress {
    description = "Allow ALB to route traffic to ECS tasks in private subnets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "order_platform_alb_sg"
  }
}