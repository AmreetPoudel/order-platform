data "aws_ssm_parameter" "username" {
  name            = var.ssm_username_path
  with_decryption = true
}

data "aws_ssm_parameter" "token" {
  name            = var.ssm_token_path
  with_decryption = true
}

resource "aws_secretsmanager_secret" "dockerhub" {
  name = var.secret_name
}

resource "aws_secretsmanager_secret_version" "dockerhub" {
  secret_id = aws_secretsmanager_secret.dockerhub.id
  secret_string = jsonencode({
    username = data.aws_ssm_parameter.username.value
    password = data.aws_ssm_parameter.token.value
  })
}