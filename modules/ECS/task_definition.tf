# ==============================================================================
# modules/ECS/task_definition.tf
#
# Defines the 3 ECS Fargate Task Definitions:
#   1. frontend : React UI (Port 80)
#   2. api      : Express API Backend (Port 4000)
#   3. worker   : RabbitMQ Consumer (Background process, No ports)
# ==============================================================================

# ==============================================================================
# 1. FRONTEND TASK DEFINITION
# ==============================================================================
resource "aws_ecs_task_definition" "frontend" {
  family                   = "order-platform-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = var.frontend_image
      essential = true

      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]

      repositoryCredentials = {
        credentialsParameter = var.dockerhub_secret_arn
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/order-platform-frontend"
          "awslogs-region"        = "ap-south-1"
          "awslogs-stream-prefix" = "frontend"
        }
      }
    }
  ])

  tags = {
    Name = "order-platform-frontend-task"
  }
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/order-platform-frontend"
  retention_in_days = 7
}

# ==============================================================================
# 2. API BACKEND TASK DEFINITION
# ==============================================================================
resource "aws_ecs_task_definition" "api" {
  family                   = "order-platform-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = var.api_image
      essential = true

      portMappings = [
        {
          containerPort = 4000
          protocol      = "tcp"
        }
      ]

      repositoryCredentials = {
        credentialsParameter = var.dockerhub_secret_arn
      }

      # Environment variables point to the Stateful EC2 Private IP
      environment = [
        { name = "PGHOST", value = var.pg_host },
        { name = "PGPORT", value = "5432" },
        { name = "PGUSER", value = "postgres" },
        { name = "PGDATABASE", value = "postsdb" },
        { name = "REDIS_HOST", value = var.redis_host },
        { name = "REDIS_PORT", value = "6379" },
        { name = "RABBITMQ_HOST", value = var.rabbitmq_host }
      ]

      # Secrets dynamically fetched from AWS Systems Manager Parameter Store
      secrets = [
        { name = "PGPASSWORD", valueFrom = "${var.ssm_parameter_path_prefix}pg-password" },
        { name = "RABBITMQ_USER", valueFrom = "${var.ssm_parameter_path_prefix}rabbitmq-user" },
        { name = "RABBITMQ_PASSWORD", valueFrom = "${var.ssm_parameter_path_prefix}rabbitmq-password" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/order-platform-api"
          "awslogs-region"        = "ap-south-1"
          "awslogs-stream-prefix" = "api"
        }
      }
    }
  ])

  tags = {
    Name = "order-platform-api-task"
  }
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/order-platform-api"
  retention_in_days = 7
}

# ==============================================================================
# 3. WORKER (CONSUMER) TASK DEFINITION
# ==============================================================================
resource "aws_ecs_task_definition" "worker" {
  family                   = "order-platform-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "worker"
      image     = var.worker_image
      essential = true

      # Worker does not listen on any HTTP port — it only consumes messages from RabbitMQ

      repositoryCredentials = {
        credentialsParameter = var.dockerhub_secret_arn
      }

      environment = [
        { name = "PGHOST", value = var.pg_host },
        { name = "PGPORT", value = "5432" },
        { name = "PGUSER", value = "postgres" },
        { name = "PGDATABASE", value = "postsdb" },
        { name = "REDIS_HOST", value = var.redis_host },
        { name = "REDIS_PORT", value = "6379" },
        { name = "RABBITMQ_HOST", value = var.rabbitmq_host }
      ]

      secrets = [
        { name = "PGPASSWORD", valueFrom = "${var.ssm_parameter_path_prefix}pg-password" },
        { name = "RABBITMQ_USER", valueFrom = "${var.ssm_parameter_path_prefix}rabbitmq-user" },
        { name = "RABBITMQ_PASSWORD", valueFrom = "${var.ssm_parameter_path_prefix}rabbitmq-password" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/order-platform-worker"
          "awslogs-region"        = "ap-south-1"
          "awslogs-stream-prefix" = "worker"
        }
      }
    }
  ])

  tags = {
    Name = "order-platform-worker-task"
  }
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/order-platform-worker"
  retention_in_days = 7
}