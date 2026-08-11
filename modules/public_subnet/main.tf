resource "aws_subnet" "order_platform_public_subnet" {
      vpc_id= var.order_platform_vpc_id
      cidr_block = var.order_platform_public_subnet_cidr
      map_public_ip_on_launch = true
      availability_zone= var.public_subnet_az
      tags={
            Name= var.subnet_name
      }


}