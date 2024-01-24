terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # version = "~> 4.0"
    }
  }
}

# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       # version = "~> 4.0"
#     }
#   }
#   backend "s3" {
#     bucket = var.tfstate_s3_bucket_name,
#     key    = var.tfstate_s3_object_key,
#     region = var.aws_region
#   }

# }

# terraform {
#   backend "s3" {
#     bucket = var.tfstate_s3_bucket_name,
#     key    = var.tfstate_s3_object_key,
#     region = var.aws_region
#   }
# }

provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
}

#################
# Local variables
#################

# paths to Lambda zip files and tag variables

locals {
  # airtable_lambda_zip = "../deploy/lambda_function.zip"
    airtable_to_sqs_zip = "../deploy/airtable_to_sqs.zip"
    stage_s3_to_prod_s3_zip = "../deploy/stage_s3_to_prod_s3.zip"
    mros_append_daily_data_zip = "../deploy/mros_append_daily_data.zip"
    mros_insert_into_dynamodb_zip = "../deploy/mros_insert_into_dynamodb.zip"
    name_tag = "mros"
}
