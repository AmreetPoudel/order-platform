resource "aws_ecs_cluster" "order_platform_ecs_cluster" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"   # gives you CloudWatch Container Insights metrics
  }

  tags = {
    Name = var.cluster_name
  }
}