variable "vpc_id" {
  type = string
}
variable "alb_sg_id" {
  type = string
}
variable "alb_arn" {
  type = string
}
variable "private_subnet_ids" {
  type = list(string)
}
variable "dockerhub_secret_arn" {
  type = string
}
variable "ssm_parameter_path_prefix" {
  type = string
}
variable "cluster_name" {
  type = string
}