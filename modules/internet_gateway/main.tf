resource "aws_internet_gateway" "order_platform_igw" {
    vpc_id = var.order_platform_vpc_id
      tags = {
    Name = "order_platform_igw"
  }
}