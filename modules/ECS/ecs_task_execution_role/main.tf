resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.name_prefix}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = {
    Name = "${var.name_prefix}-ecs-execution-role"
  }
}

# AWS-managed policy: covers ECR pull + basic CloudWatch Logs write
# Harmless to attach even though you're on Docker Hub, not ECR -
# it also grants logs:CreateLogStream / logs:PutLogEvents, which you need regardless of registry.
resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Custom inline policy: Docker Hub credentials (Secrets Manager) + SSM Parameter Store read
resource "aws_iam_role_policy" "ecs_task_execution_custom" {
  name = "${var.name_prefix}-ecs-execution-custom-policy"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DockerHubCredentials"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.dockerhub_secret_arn
      },
      {
        Sid      = "SSMParameterStoreRead"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
        Resource = "arn:aws:ssm:*:*:parameter${var.ssm_parameter_path_prefix}*"
      },
      {
        Sid      = "KMSDecryptForSecureString"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = "*"
      }
    ]
  })
}