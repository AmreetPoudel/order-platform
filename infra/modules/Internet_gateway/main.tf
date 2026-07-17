resource "aws_internet_gateway" "gw" {
  vpc_id = var.order_platform_vpc_id

  tags = {
    Name = "main"
  }
}