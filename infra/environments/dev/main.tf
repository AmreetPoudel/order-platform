terraform {
  backend "s3" {
    bucket         = "order-platform-tf-state-891274465984"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    use_lockfile = true
    encrypt        = true
  }
}
