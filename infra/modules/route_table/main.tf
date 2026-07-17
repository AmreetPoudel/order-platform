resource "aws_internet_gateway" "order_platform_gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}