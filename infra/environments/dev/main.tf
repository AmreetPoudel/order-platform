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

module "private_subnet_a" {
  source= "../../../modules/private_subnet"
  order_platform_private_subnet_cidr = "10.0.1.0/24"
  order_platform_vpc_id = module.VPC.order_platform_vpc_id
  private_subnet_az="ap-south-1a"
  }

module "private_subnet_b" {
  source= "../../../modules/private_subnet"
  order_platform_private_subnet_cidr = "10.0.2.0/24"
  order_platform_vpc_id = module.VPC.order_platform_vpc_id
  private_subnet_az="ap-south-1b"

  }

module "public_subnet_a" {
  source= "../../../modules/public_subnet"
  order_platform_public_subnet_cidr = "10.0.3.0/24"
  order_platform_vpc_id = module.VPC.order_platform_vpc_id
  public_subnet_az = "ap-south-1a"
  subnet_name = "order_platform_public_subnet_a"
}
module "public_subnet_b" {
  source= "../../../modules/public_subnet"
  order_platform_public_subnet_cidr = "10.0.4.0/24"
  order_platform_vpc_id = module.VPC.order_platform_vpc_id
  public_subnet_az = "ap-south-1b"
  subnet_name = "order_platform_public_subnet_b"
}

module "internet_gateway" {
  source= "../../../modules/internet_gateway"
  order_platform_vpc_id = module.VPC.order_platform_vpc_id
}

module "nat_gateway_a" {
  source= "../../../modules/nat_gateway"
  order_platform_public_subnet_id = module.public_subnet_a.order_platform_public_subnet_id
  depends_on = [module.internet_gateway]
}

module "nat_gateway_b" {
  source= "../../../modules/nat_gateway"
  order_platform_public_subnet_id = module.public_subnet_b.order_platform_public_subnet_id
  depends_on = [module.internet_gateway]
}

module "route_table_public_subnet_a" {
  source= "../../../modules/route_table"
  order_platform_vpc_id = module.VPC.order_platform_vpc_id
  order_platform_nat_gateway_id = module.nat_gateway_a.order_platform_nat_gateway_id
  order_platform_private_subnet_id = module.private_subnet_a.order_platform_private_subnet_id
  order_platform_internet_gateway_id = module.internet_gateway.order_platform_internet_gateway_id
  order_platform_public_subnet_id = module.public_subnet_a.order_platform_public_subnet_id
}
module "route_table_public_subnet_b" {
  source= "../../../modules/route_table"
  order_platform_vpc_id = module.VPC.order_platform_vpc_id
  order_platform_nat_gateway_id = module.nat_gateway_b.order_platform_nat_gateway_id
  order_platform_private_subnet_id = module.private_subnet_b.order_platform_private_subnet_id
  order_platform_internet_gateway_id = module.internet_gateway.order_platform_internet_gateway_id
  order_platform_public_subnet_id = module.public_subnet_b.order_platform_public_subnet_id
}

module "SG" {
  source= "../../../modules/SG"
  order_platform_vpc_id = module.VPC.order_platform_vpc_id
}

module "ALB" {
  source= "../../../modules/ALB"
  order_platform_public_subnet_id = [
    module.public_subnet_a.order_platform_public_subnet_id,
    module.public_subnet_b.order_platform_public_subnet_id
  ]
  order_platform_alb_sg_id = [module.SG.order_platform_alb_sg_id]
}