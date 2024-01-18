terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # version = "~> 4.0"
    }
  }
}

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
    name_tag = "mros"
}
