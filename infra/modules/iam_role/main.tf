resource "aws_iam_role" "order_platform_ec2_role" {
  name = "order_platform_ec2_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  ## trust policy only ec2 can assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    tag-key = "order_platform_ec2_role"
  }
}

resource "aws_iam_role_policy" "order_platform_ssm_read" {
  name = "order_platform_ssm_read"
  role = aws_iam_role.order_platform_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter", "ssm:GetParameters"]
      Resource = "arn:aws:ssm:ap-south-1:*:parameter/order-platform/*"
    }]
  })
}

resource "aws_iam_instance_profile" "order_platform_profile" {
  name = "order_platform_ec2_profile"
  role = aws_iam_role.order_platform_ec2_role.name
}