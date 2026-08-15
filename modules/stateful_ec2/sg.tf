# ==============================================================================
# modules/stateful_ec2/sg.tf
#
# Security Group for the Stateful EC2 host (PostgreSQL, Redis, RabbitMQ).
# ==============================================================================

resource "aws_security_group" "stateful_ec2_sg" {
  name        = "order-platform-stateful-ec2-sg"
  description = "Controls traffic to PostgreSQL, Redis, and RabbitMQ on EC2"
  vpc_id      = var.vpc_id

  # ----------------------------------------------------------------------------
  # 1. PostgreSQL (Port 5432)
  # Allow incoming queries from within VPC (where ECS Fargate tasks reside)
  # ----------------------------------------------------------------------------
  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # ----------------------------------------------------------------------------
  # 2. Redis (Port 6379)
  # Allow cache operations from within VPC
  # ----------------------------------------------------------------------------
  ingress {
    description = "Redis from VPC"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # ----------------------------------------------------------------------------
  # 3. RabbitMQ AMQP (Port 5672)
  # Allow message publishing and consuming from within VPC
  # ----------------------------------------------------------------------------
  ingress {
    description = "RabbitMQ AMQP from VPC"
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # ----------------------------------------------------------------------------
  # 4. RabbitMQ Management Dashboard (Port 15672)
  # Internal diagnostics
  # ----------------------------------------------------------------------------
  ingress {
    description = "RabbitMQ Management UI within VPC"
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # ----------------------------------------------------------------------------
  # 5. SSH (Port 22)
  # ----------------------------------------------------------------------------
  ingress {
    description = "SSH from within VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # ----------------------------------------------------------------------------
  # Outbound Egress
  # Allows EC2 to pull Docker images and install packages via NAT Gateway
  # ----------------------------------------------------------------------------
  egress {
    description = "Allow all outbound via NAT Gateway"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "order-platform-stateful-ec2-sg"
  }
}
