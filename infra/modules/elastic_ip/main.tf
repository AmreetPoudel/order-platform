resource "aws_eip" "order_platform_eip" {
  domain   = "vpc"
tags = {
    Name = "order_platform_eip"
  }
}