resource "aws_vpc" "order_platform_vpc"{
    cidr_block= var.vpc_cidr_block
    tags={
        Name="order_platform_vpc"
    }

}