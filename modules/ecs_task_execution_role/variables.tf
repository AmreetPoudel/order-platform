variable "name_prefix" {
  type        = string
  description = "Prefix for IAM role and policy names"
}

variable "dockerhub_secret_arn" {
  type        = string
  description = "ARN of the Secrets Manager secret storing Docker Hub credentials"
}

variable "ssm_parameter_path_prefix" {
  type        = string
  description = "SSM Parameter Store path prefix this role can read, e.g. /order-platform/"
}