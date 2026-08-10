output "order_platform_vpc_id {
    description = "VPC ID of the order_platform VPC"
    value=aws_vpc.order_platform_vpc.id
}
