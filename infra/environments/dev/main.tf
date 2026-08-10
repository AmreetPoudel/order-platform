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
  source = "../../modules/VPC"
  vpc_cidr_block = "10.0.0.0/16"
}

module "private_subnet" {
  source= "../../modules/private_subnet"
  order_platform_private_subnet_cidr = "10.0.1.0/24"
  }

