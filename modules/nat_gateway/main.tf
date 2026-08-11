resource "aws_eip" "order_platform_nat_eip" {
  domain = "vpc"

  tags = {
    Name = "order_platform_nat_eip"
  }
}



resource "aws_nat_gateway" "order_platform_nat_gw" {
  subnet_id     = var.order_platform_public_subnet_id
  allocation_id = aws_eip.order_platform_nat_eip.id

  tags = {
    Name = "order_platform_nat_gw"
  }
}