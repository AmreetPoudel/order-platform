resource "aws_route_table" "order_platform_private_route_table" {
    vpc_id = var.order_platform_vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = var.order_platform_nat_gateway_id
  }

  tags = {
    Name = "order_platform_private_route_table"
  }
}


resource "aws_route_table_association" "order_platform_private_route_table_association" {
  subnet_id      = var.order_platform_private_subnet_id
  route_table_id = aws_route_table.order_platform_private_route_table.id
}


resource  "aws_route_table" "order_platform_public_route_table" {
  vpc_id = var.order_platform_vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.order_platform_internet_gateway_id
  }

  tags = {
    Name = "order_platform_public_route_table"
  }
}

resource "aws_route_table_association" "order_platform_public_route_table_association" {
  subnet_id      = var.order_platform_public_subnet_id
  route_table_id = aws_route_table.order_platform_public_route_table.id
}