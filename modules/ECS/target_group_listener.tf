# ==============================================================================
# modules/ECS/target_group_listener.tf
#
# Configures Target Groups and Path-Based Routing on the ALB:
#   - Path "/" (Default)  --> Forward to Frontend Target Group (Port 80)
#   - Path "/api/*"       --> Forward to API Target Group (Port 4000)
#   - Path "/health"      --> Forward to API Target Group (Port 4000)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Frontend Target Group (Port 80)
# ------------------------------------------------------------------------------
resource "aws_lb_target_group" "frontend" {
  name        = "order-platform-frontend-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for Fargate (uses awsvpc network mode)

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "order-platform-frontend-tg"
  }
}

# ------------------------------------------------------------------------------
# 2. API Backend Target Group (Port 4000)
# ------------------------------------------------------------------------------
resource "aws_lb_target_group" "api" {
  name        = "order-platform-api-tg"
  port        = 4000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for Fargate

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "order-platform-api-tg"
  }
}

# ------------------------------------------------------------------------------
# 3. ALB Port 80 Listener (Default Action: Frontend UI)
# ------------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = var.alb_arn
  port              = 80
  protocol          = "HTTP"

  # By default, any request (e.g. http://<ALB-DNS>/) serves the Frontend React App
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# ------------------------------------------------------------------------------
# 4. ALB Listener Rule (Path-Based Routing for /api/* and /health)
# ------------------------------------------------------------------------------
resource "aws_lb_listener_rule" "api_routing" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10 # Evaluated before default action

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  # Route requests starting with /api/ or hitting /health to the backend API container
  condition {
    path_pattern {
      values = ["/api/*", "/health"]
    }
  }
}