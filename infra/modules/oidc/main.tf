resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]
### a certificate fingerprint AWS uses to verify it's really talking to GitHub's genuine token service 
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
}


### simple who issues =url.  to whom = client_id_list is_client_github_fingerprint_verify=thumbprint_list



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
          "token.actions.githubusercontent.com:sub" = [
            "repo:AmreetPoudel/order-platform:*",
            "repo:AmreetPoudel@*/order-platform@*:*"
          ]
        }
      }
    }]
  })
}


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