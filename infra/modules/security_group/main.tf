resource "aws_security_group" "order_platform_sg" {
  name        = "order-platform-sg"
  description = "Allow specific inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.order_platform_vpc.id

  tags = {
    Name = "order-platform-sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.order_platform_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.order_platform_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
     security_group_id = aws_security_group.order_platform_sg.id
     cidr_ipv4         = var.ssh_ip
     from_port         = 22
     ip_protocol       = "tcp"
     to_port           = 22
   }

resource "aws_vpc_security_group_ingress_rule" "api" {
  security_group_id = aws_security_group.order_platform_sg.id
  cidr_ipv4         = aws_vpc.order_platform_vpc.cidr_block
  from_port         = 4000
  ip_protocol       = "tcp"
  to_port           = 4000
}

resource "aws_vpc_security_group_ingress_rule" "rabbitMQ" {
  security_group_id = aws_security_group.order_platform_sg.id
  cidr_ipv4         = aws_vpc.order_platform_vpc.cidr_block
  from_port         = 5672
  ip_protocol       = "tcp"
  to_port           = 5672
}

resource "aws_vpc_security_group_ingress_rule" "redis" {
  security_group_id = aws_security_group.order_platform_sg.id
  cidr_ipv4         = aws_vpc.order_platform_vpc.cidr_block
  from_port         = 6379
  ip_protocol       = "tcp"
  to_port           = 6379
}

resource "aws_vpc_security_group_ingress_rule" "postgres" {
  security_group_id = aws_security_group.order_platform_sg.id
  cidr_ipv4         = aws_vpc.order_platform_vpc.cidr_block
  from_port         = 5432
  ip_protocol       = "tcp"
  to_port           = 5432
}

resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.order_platform_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}