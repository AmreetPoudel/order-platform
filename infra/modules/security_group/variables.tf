variable "ssh_ip" {
  type        = string
  description = "My home or office public IP address"
  default     = "182.09.81.22/32"
}

variable "order_platform_vpc_id" {
  type        = string
  description = "VPC ID this security group belongs to"
}


variable "order_platform_public_subnet_id"{
   type        = string
  description = "VPC CIDR block, for VPC-internal-only rules"
}