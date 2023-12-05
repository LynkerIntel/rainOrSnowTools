# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       # version = "~> 4.0"
#     }
#   }
# }

# # cloud provider
# provider "aws" {
#   region = var.aws_region
#   profile = var.profile
# }

# # terraform backend
provider "aws" {
  region  = var.aws_region
  # version = "~> 3.0"
}

# S3 bucket for rainOrSnowTools R package
resource "aws_s3_bucket" "rpkg_bucket" {
  bucket = var.s3_bucket_name
  acl    = "private"
  tags = {
    Name        = "rainorsnowtools"
    Environment = "dev"
  }
}