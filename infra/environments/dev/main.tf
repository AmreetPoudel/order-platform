module "vpc" {
  source          = "../../modules/vpc"
  vpc_cidr        = "10.0.0.0/16"
  subnet_cidr     = "10.0.1.0/24"   
  az              = "ap-south-1a"
  vpc_tag_name    = "order_platform_vpc"
  subnet_tag_name = "order_platform_subnet"
}

module "security_group" {
  source                  = "../../modules/security_group"
  order_platform_vpc_id   = module.vpc.order_platform_vpc_id
  order_platform_vpc_cidr = "10.0.0.0/16"
  ssh_ip                  = var.ssh_ip
}

module "internet_gateway" {
  source                 = "../../modules/Internet_gateway"
  order_platform_vpc_id  = module.vpc.order_platform_vpc_id
}

module "route_table" {
  source                 = "../../modules/route_table"
  order_platform_vpc_id  = module.vpc.order_platform_vpc_id
  order_platform_gw_id   = module.internet_gateway.order_platform_gw_id
}

resource "aws_route_table_association" "order_platform_rta" {
  subnet_id      = module.vpc.order_platform_public_subnet_id
  route_table_id = module.route_table.order_platform_rt_id
}

module "elastic_ip" {
  source = "../../modules/elastic_ip"
}

resource "aws_key_pair" "order_platform_key" {
  key_name   = "order_platform_key"
  public_key = file("${path.module}/order_platform_key.pub")
}

module "ec2" {
  source                        = "../../modules/ec2"
  order_platform_ami_id         = var.ami_id
  order_platform_instance_type  = "t3.micro"
  order_platform_subnet_id      = module.vpc.order_platform_public_subnet_id
  order_platform_sg_ids         = [module.security_group.order_platform_sg_id]
  order_platform_key_name       = aws_key_pair.order_platform_key.key_name
  order_platform_environment    = "dev"
}

resource "aws_eip_association" "order_platform_eip_assoc" {
  instance_id   = module.ec2.order_platform_instance_id
  allocation_id = module.elastic_ip.order_platform_eip_allocation_id
}

module "iam_role" {
  source = "../../modules/iam_role"
}
