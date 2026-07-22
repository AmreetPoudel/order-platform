variable "ssh_ip" {
  type        = string
  description = "My home or office public IP address"
  default     = "27.34.64.182/32"
}

variable "order_platform_vpc_id" {
  type        = string
  description = "VPC ID this security group belongs to"
}


variable "order_platform_vpc_cidr" {
  type        = string
  description = "VPC CIDR block, for VPC-internal-only ingress rules"
}