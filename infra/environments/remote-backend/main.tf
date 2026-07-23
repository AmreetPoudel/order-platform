terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_s3_bucket" "order_platform_tf_state" {
  bucket = "order-platform-tf-state-${data.aws_caller_identity.current.account_id}"

  lifecycle {
    prevent_destroy = true
  }
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_versioning" "order_platform_tf_state_versioning" {
  bucket = aws_s3_bucket.order_platform_tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "order_platform_tf_state_encryption" {
  bucket = aws_s3_bucket.order_platform_tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "order_platform_tf_state_block" {
  bucket = aws_s3_bucket.order_platform_tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

