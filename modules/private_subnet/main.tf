resource "aws_subnet" "order_platform_private_subnet" {
    vpc_id= var.order_platform_vpc_id
    cidr_block= var.order_platform_private_subnet_cidr
    map_public_ip_on_launch = false
    availability_zone= var.private_subnet_az

    tags= {
        Name="order_platform_private_subnet"
    }
}