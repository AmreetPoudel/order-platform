resource "aws_route_table" "order_platform_route_table" {
  vpc_id = var.order_platform_vpc_id

  route {
  cidr_block = "0.0.0.0/0"       
  gateway_id = var.order_platform_gw_id  
  }

 

  tags = {
    Name = "order_platform_route_table"
  }
}