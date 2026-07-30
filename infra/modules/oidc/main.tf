# ============================================================
# OIDC Identity Provider - tells AWS to trust GitHub's tokens
# who issues        = url
# who receives it   = client_id_list
# how AWS verifies  = thumbprint_list (GitHub's cert fingerprint)
# ============================================================
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
}

# ============================================================
# IAM Role - who is allowed to assume it (repo + branch scoped)
# ============================================================
resource "aws_iam_role" "github_actions_cd" {
  name = "order_platform_github_actions_cd"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # Only main and dev branches can assume this role.
          # NOT "repo:owner/repo:*" -- that would also allow
          # pull_request-triggered runs (including from forks) to assume it.
          "token.actions.githubusercontent.com:sub" = [
            "repo:AmreetPoudel/order-platform:ref:refs/heads/main",
            "repo:AmreetPoudel/order-platform:ref:refs/heads/dev",
            "repo:AmreetPoudel/order-platform:ref:refs/heads/oidc"
          ]
        }
      }
    }]
  })
}

# ============================================================
# Permission Policy - what the assumed role can do (SSM)
# ============================================================
resource "aws_iam_role_policy" "github_actions_ssm" {
  name = "order_platform_github_ssm_send_command"
  role = aws_iam_role.github_actions_cd.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:SendCommand", "ssm:GetCommandInvocation"]
      Resource = "*"
    }]
  })
}

# ============================================================
# Permission Policy - what the assumed role can do (S3 upload)
# ============================================================
resource "aws_iam_role_policy" "github_actions_s3_deploy" {
  name = "order_platform_github_s3_deploy"
  role = aws_iam_role.github_actions_cd.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "arn:aws:s3:::order-platform-tf-state-891274465984/deploy/dev/artifacts/*"
    }]
  })
}
