output "order_platform_dns_name" {
  value       = aws_lb.order_platform_alb.dns_name
  description = "DNS name of the order_platform ALB"
}
output "alb_arn" {
  value       = aws_lb.order_platform_alb.arn
  description = "ARN of the order_platform ALB"
}