# ==============================================================================
# infra/environments/dev/main.tf
#
# Main entrypoint for Dev Environment Infrastructure.
# Deploys:
#   1. Networking: VPC, Public/Private Subnets (Multi-AZ), IGW, NAT Gateways, Route Tables
#   2. Stateful Layer (EC2): PostgreSQL, Redis, RabbitMQ in Private Subnet
#   3. Stateless Layer (ECS Fargate): Frontend (React), API (Express), Worker (Queue Consumer)
#   4. Edge / Routing: Public Application Load Balancer with Path-Based Routing
# ==============================================================================

terraform {
  backend "s3" {
    bucket       = "order-platform-tf-state-891274465984"
    key          = "dev/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}

# ==============================================================================
# 1. NETWORKING (VPC & Subnets)
# ==============================================================================
module "VPC" {
  source         = "../../../modules/VPC"
  vpc_cidr_block = "10.0.0.0/16"
}

module "private_subnet_a" {
  source                             = "../../../modules/private_subnet"
  order_platform_vpc_id              = module.VPC.order_platform_vpc_id
  order_platform_private_subnet_cidr = "10.0.1.0/24"
  private_subnet_az                  = "ap-south-1a"
}

module "private_subnet_b" {
  source                             = "../../../modules/private_subnet"
  order_platform_vpc_id              = module.VPC.order_platform_vpc_id
  order_platform_private_subnet_cidr = "10.0.2.0/24"
  private_subnet_az                  = "ap-south-1b"
}

module "public_subnet_a" {
  source                            = "../../../modules/public_subnet"
  order_platform_vpc_id             = module.VPC.order_platform_vpc_id
  order_platform_public_subnet_cidr = "10.0.3.0/24"
  public_subnet_az                  = "ap-south-1a"
  subnet_name                       = "order_platform_public_subnet_a"
}

module "public_subnet_b" {
  source                            = "../../../modules/public_subnet"
  order_platform_vpc_id             = module.VPC.order_platform_vpc_id
  order_platform_public_subnet_cidr = "10.0.4.0/24"
  public_subnet_az                  = "ap-south-1b"
  subnet_name                       = "order_platform_public_subnet_b"
}

module "internet_gateway" {
  source                = "../../../modules/internet_gateway"
  order_platform_vpc_id = module.VPC.order_platform_vpc_id
}

module "nat_gateway_a" {
  source                           = "../../../modules/nat_gateway"
  order_platform_public_subnet_id  = module.public_subnet_a.order_platform_public_subnet_id
  depends_on                       = [module.internet_gateway]
}

module "nat_gateway_b" {
  source                           = "../../../modules/nat_gateway"
  order_platform_public_subnet_id  = module.public_subnet_b.order_platform_public_subnet_id
  depends_on                       = [module.internet_gateway]
}

module "route_table_public_subnet_a" {
  source                             = "../../../modules/route_table"
  order_platform_vpc_id              = module.VPC.order_platform_vpc_id
  order_platform_nat_gateway_id      = module.nat_gateway_a.order_platform_nat_gateway_id
  order_platform_private_subnet_id   = module.private_subnet_a.order_platform_private_subnet_id
  order_platform_internet_gateway_id = module.internet_gateway.order_platform_internet_gateway_id
  order_platform_public_subnet_id    = module.public_subnet_a.order_platform_public_subnet_id
}

module "route_table_public_subnet_b" {
  source                             = "../../../modules/route_table"
  order_platform_vpc_id              = module.VPC.order_platform_vpc_id
  order_platform_nat_gateway_id      = module.nat_gateway_b.order_platform_nat_gateway_id
  order_platform_private_subnet_id   = module.private_subnet_b.order_platform_private_subnet_id
  order_platform_internet_gateway_id = module.internet_gateway.order_platform_internet_gateway_id
  order_platform_public_subnet_id    = module.public_subnet_b.order_platform_public_subnet_id
}

# ==============================================================================
# 2. APPLICATION LOAD BALANCER & SECURITY GROUPS
# ==============================================================================
module "SG" {
  source                = "../../../modules/SG"
  order_platform_vpc_id = module.VPC.order_platform_vpc_id
}

module "ALB" {
  source = "../../../modules/ALB"
  order_platform_public_subnet_id = [
    module.public_subnet_a.order_platform_public_subnet_id,
    module.public_subnet_b.order_platform_public_subnet_id
  ]
  order_platform_alb_sg_id = [module.SG.order_platform_alb_sg_id]
}

# ==============================================================================
# 3. SECRETS (Docker Hub Credentials in Secrets Manager)
# ==============================================================================
module "dockerhub_secret" {
  source            = "../../../modules/dockerhub_secret"
  ssm_username_path = "/order-platform/dockerhub-username"
  ssm_token_path    = "/order-platform/dockerhub-token"
  secret_name       = "order-platform/dockerhub-credentials"
}

# ==============================================================================
# 4. STATEFUL LAYER (EC2: PostgreSQL, Redis, RabbitMQ)
# ==============================================================================
module "stateful_ec2" {
  source            = "../../../modules/stateful_ec2"
  vpc_id            = module.VPC.order_platform_vpc_id
  private_subnet_id = module.private_subnet_a.order_platform_private_subnet_id
  instance_type     = "t3.small"
}

# ==============================================================================
# 5. STATELESS LAYER (ECS FARGATE: Frontend, API Backend, Worker)
# ==============================================================================
module "ecs" {
  source                    = "../../../modules/ECS"
  vpc_id                    = module.VPC.order_platform_vpc_id
  alb_sg_id                 = module.SG.order_platform_alb_sg_id
  alb_arn                   = module.ALB.alb_arn
  private_subnet_ids        = [
    module.private_subnet_a.order_platform_private_subnet_id,
    module.private_subnet_b.order_platform_private_subnet_id
  ]
  dockerhub_secret_arn      = module.dockerhub_secret.secret_arn
  ssm_parameter_path_prefix = "/order-platform/"
  cluster_name              = "order-platform-cluster"

  # Pass the Private IP of the Stateful EC2 instance so Fargate tasks can reach DB & Queue
  pg_host                   = module.stateful_ec2.private_ip
  redis_host                = module.stateful_ec2.private_ip
  rabbitmq_host             = module.stateful_ec2.private_ip

  # Container Images (Replace with your Docker Hub repo/tag)
  api_image                 = "amritpoudel/order-platform-api:latest"
  frontend_image            = "amritpoudel/order-platform-frontend:latest"
  worker_image              = "amritpoudel/order-platform-worker:latest"

  desired_count             = 1
}