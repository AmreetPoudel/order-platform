variable "order_platform_vpc_id" {
  type        = string
  description = "VPC ID this security group belongs to"
}


variable "order_platform_vpc_cidr" {
  type        = string
  description = "VPC CIDR block, for VPC-internal-only ingress rules"
}

variable "ssh_ip" {
  type        = string
  description = "Trusted public IP for SSH ingress, CIDR notation"
  # no default — forces an explicit value from the caller, every time
}