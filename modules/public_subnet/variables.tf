
variable "order_platform_public_subnet_cidr"{
    type       = string
    description= "public subnet cidr block"
}
variable "order_platform_vpc_id" {
    type        = string
    description = "VPC ID of the order_platform VPC"
}
variable "public_subnet_az" {
    type        = string
    description = "Availability Zone for the public subnet"
}
variable "subnet_name" {
  type        = string
  description = "Name tag for the subnet"
}