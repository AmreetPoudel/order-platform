output "order_platform_public_ip"{
    value= aws_eip.order_platform_eip.public_ip
}

output "order_platform_public_eip_id"{
    value= aws_eip.order_platform_eip.id
}
