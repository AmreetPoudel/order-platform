output "order_platform_vpc_id"{
    value= aws_vpc.order_platform_vpc.id
}

output "order_platform_public_subnet_id"{
    value= aws_subnet.order_platform_subnet_public.id
}