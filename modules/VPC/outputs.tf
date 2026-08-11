output "order_platform_vpc_id" {
  value = aws_vpc.order_platform_vpc.id
  description = "VPC ID of the order_platform VPC"
}
