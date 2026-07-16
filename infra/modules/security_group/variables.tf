variable "ssh_ip" {
  type        = string
  description = "My home or office public IP address"
  default     = "182.09.81.22/32"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID this security group belongs to"
}


variable "subnet_id"{
   type        = string
  description = "VPC CIDR block, for VPC-internal-only rules"
}