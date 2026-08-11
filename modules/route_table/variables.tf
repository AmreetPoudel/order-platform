variable order_platform_vpc_id {
  type        = string
    description = "VPC ID of the order_platform VPC"
}

variable order_platform_nat_gateway_id {
  type        = string
  description = "NAT Gateway ID of the order_platform NAT Gateway"
}

variable order_platform_private_subnet_id {
  type        = string
  description = "Private Subnet ID of the order_platform Private Subnet"
}

variable order_platform_internet_gateway_id {
  type        = string
  description = "Internet Gateway ID of the order_platform Internet Gateway"
}
variable order_platform_public_subnet_id {
  type        = string
  description = "Public Subnet ID of the order_platform Public Subnet"
}