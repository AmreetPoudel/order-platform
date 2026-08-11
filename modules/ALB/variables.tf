variable "order_platform_public_subnet_id" {
  type        = list(string)
  description = "Public subnet ID of the order_platform VPC"
}

variable "order_platform_alb_sg_id" {
  type        = list(string)
  description = "Security Group ID of the order_platform ALB"
}