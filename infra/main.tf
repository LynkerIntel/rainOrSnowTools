# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       # version = "~> 4.0"
#     }
#   }
# }

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # version = "~> 4.0"
    }
  }
  backend "s3" {
    key    = "terraform.tfstate"
  }

}

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
    mros_airtable_to_sqs_zip = "../deploy/mros_airtable_to_sqs.zip"
    mros_stage_to_prod_zip = "../deploy/mros_stage_to_prod.zip"
    mros_append_daily_data_zip = "../deploy/mros_append_daily_data.zip"
    mros_insert_into_dynamodb_zip = "../deploy/mros_insert_into_dynamodb.zip"
    name_tag = "mros"
}
