output "order_platform_alb_sg_id" {
  value       = aws_security_group.order_platform_alb_sg.id
  description = "Security Group ID of the order_platform ALB"
}