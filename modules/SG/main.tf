resource "aws_security_group" "order_platform_alb_sg" {
  name        = "order_platform_alb_sg"
  description = "Allow HTTP and HTTPS traffic to alb"
  vpc_id      = var.order_platform_vpc_id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}