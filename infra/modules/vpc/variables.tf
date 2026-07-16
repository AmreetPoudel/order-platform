variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}


variable "vpc_tag_name" {
  description = "vpc"
  type        = string
  default     = "order_platform_vpc"
}

variable "subnet_tag_name" {
  description = "subnet"
  type        = string
  default     = "order_platform_subnet"
}

variable "az" {
  description = "Availability zone for the subnet"
  type        = string
  default     = "ap-south-1a"
}