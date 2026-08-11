resource "aws_lb" "order_platform_alb" {
    name               = "order_platform_alb"
    internal           = false
    load_balancer_type = "application"
    subnets            = var.order_platform_public_subnet_id
    security_groups      = var.order_platform_alb_sg_id

tags = {
        Name = "order_platform_alb"
    }
}