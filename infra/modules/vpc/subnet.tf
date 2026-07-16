resource "aws_subnet" "order_platform_subnet_public" {
  vpc_id     = aws_vpc.order_platform_vpc.id
  cidr_block = var.subnet_cidr
  availability_zone= var.az
  map_public_ip_on_launch = true

  tags = {
    Name = var.subnet_tag_name
  }
}