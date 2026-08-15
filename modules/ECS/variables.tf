# ==============================================================================
# modules/ECS/variables.tf
#
# Input variables for ECS Fargate Cluster, Tasks, and Services
# ==============================================================================

variable "vpc_id" {
  type        = string
  description = "VPC ID where ECS tasks and Target Groups will be created"
}

variable "alb_sg_id" {
  type        = string
  description = "Security Group ID of the Application Load Balancer"
}

variable "alb_arn" {
  type        = string
  description = "ARN of the Application Load Balancer to attach HTTP listeners"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of Private Subnet IDs where Fargate tasks will run"
}

variable "dockerhub_secret_arn" {
  type        = string
  description = "AWS Secrets Manager Secret ARN containing Docker Hub credentials"
}

variable "ssm_parameter_path_prefix" {
  type        = string
  description = "SSM Parameter Store path prefix (e.g. /order-platform/)"
  default     = "/order-platform/"
}

variable "cluster_name" {
  type        = string
  description = "Name of the ECS Cluster"
  default     = "order-platform-cluster"
}

# ------------------------------------------------------------------------------
# Container Image Tag (Single Source of Truth from S3 versions.json)
# ------------------------------------------------------------------------------
variable "image_tag" {
  type        = string
  description = "Docker image tag (Git commit SHA) for api, frontend, and worker"
  default     = "378b552df7efb62e0848df1220e2b8efcd911ee1"
}

variable "dockerhub_username" {
  type        = string
  description = "Docker Hub account/organization name"
  default     = "aamreet"
}

# ------------------------------------------------------------------------------
# Stateful EC2 Host Connections (Private IP)
# ------------------------------------------------------------------------------
variable "pg_host" {
  type        = string
  description = "Private IP address of the EC2 instance hosting PostgreSQL"
}

variable "redis_host" {
  type        = string
  description = "Private IP address of the EC2 instance hosting Redis"
}

variable "rabbitmq_host" {
  type        = string
  description = "Private IP address of the EC2 instance hosting RabbitMQ"
}

# ------------------------------------------------------------------------------
# Sizing and Replicas
# ------------------------------------------------------------------------------
variable "task_cpu" {
  type        = string
  description = "CPU units for Fargate tasks (256 = 0.25 vCPU)"
  default     = "256"
}

variable "task_memory" {
  type        = string
  description = "Memory (in MiB) for Fargate tasks (512 = 0.5 GB)"
  default     = "512"
}

variable "desired_count" {
  type        = number
  description = "Number of task replicas to run for each service"
  default     = 1
}