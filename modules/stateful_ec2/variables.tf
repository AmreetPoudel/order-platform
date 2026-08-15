# ==============================================================================
# modules/stateful_ec2/variables.tf
#
# Input variables for the Stateful EC2 instance (Postgres, Redis, RabbitMQ)
# ==============================================================================

variable "vpc_id" {
  type        = string
  description = "VPC ID where the EC2 instance will reside"
}

variable "private_subnet_id" {
  type        = string
  description = "Private Subnet ID where the EC2 instance is deployed (no public IP)"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for stateful services (e.g. t3.small or t3.medium)"
  default     = "t3.small"
}

variable "ami_id" {
  type        = string
  description = "Ubuntu 22.04 / 24.04 LTS AMI ID for ap-south-1 (optional; defaults to latest Ubuntu 24.04)"
  default     = ""
}

variable "key_name" {
  type        = string
  description = "EC2 Key Pair name for SSH access (optional)"
  default     = ""
}
