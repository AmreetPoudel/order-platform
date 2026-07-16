output "vpc_id"{
    value= aws_vpc.order_platform_vpc.id
}

output "subnet_id"{
    value= aws_subnet.order_platform_subnet_public.id
}