terraform {
  backend "s3" {
    bucket         = "order-platform-tf-state-891274465984"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    use_lockfile = true
    encrypt        = true
  }
}

module "VPC" {
  source = "../../../modules/VPC"
  vpc_cidr_block = "10.0.0.0/16"
}

module "private_subnet" {
  source= "../../../modules/private_subnet"
  order_platform_private_subnet_cidr = "10.0.1.0/24"
  order_platform_vpc_id = module.VPC.order_platform_vpc_id
  }

module "public_subnet" {
  source= "../../../modules/public_subnet"
  order_platform_public_subnet_cidr = "10.0.2.0/24"
  order_platform_vpc_id = module.VPC.order_platform_vpc_id
}

module "internet_gateway" {
  source= "../../../modules/internet_gateway"
  order_platform_vpc_id = module.VPC.order_platform_vpc_id
}

module "nat_gateway" {
  source= "../../../modules/nat_gateway"
  order_platform_public_subnet_id = module.public_subnet.order_platform_public_subnet_id
  depends_on = [module.internet_gateway]
}

module "route_table" {
  source= "../../../modules/route_table"
  order_platform_vpc_id = module.VPC.order_platform_vpc_id
  order_platform_nat_gateway_id = module.nat_gateway.order_platform_nat_gateway_id
  order_platform_private_subnet_id = module.private_subnet.order_platform_private_subnet_id
  order_platform_internet_gateway_id = module.internet_gateway.order_platform_internet_gateway_id
  order_platform_public_subnet_id = module.public_subnet.order_platform_public_subnet_id
}
module "SG" {
  source= "../../../modules/SG"
  order_platform_vpc_id = module.VPC.order_platform_vpc_id
}

module "ALB" {
  source= "../../../modules/ALB"
  order_platform_public_subnet_id = module.public_subnet.order_platform_public_subnet_id
  order_platform_alb_sg_id = module.SG.order_platform_alb_sg_id
}