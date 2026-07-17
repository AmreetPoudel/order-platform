variable "order_platform_ami_id" {
  type        = string
  description = "AMI ID for the EC2 instance"
}

variable "order_platform_instance_type" {
  type        = string
  description = "EC2 instance type"
}

variable "order_platform_subnet_id" {
  type        = string
  description = "Subnet ID to launch the instance into"
}

variable "order_platform_sg_ids" {
  type        = list(string)
  description = "List of security group IDs to attach"
}

variable "order_platform_key_name" {
  type        = string
  description = "Key pair name for SSH access"
}

variable "order_platform_environment" {
  type        = string
  description = "Deployment environment label passed to user_data"
}