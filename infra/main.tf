# Created by: Angus Watters
# Created on: 2024-12-01

# Main Terraform file for the MROS project CI/CD Pipeline:
# - Extracts daily data from Airtable of MROS observations 
# - Retrieves and adds climate data for each observation 
# - Applies QA/QC checks to the data and adds QA/QC data flags
# - Adds the new daily data to a stationary CSV and Parquet file in an S3 bucket for output data
# - Inserts the data into a DynamoDB table

# The main.tf file declares the provider, backend, and local variables for the project.
# A skeleton of the required variables can be found in the variables_template.tf file
# The Terraform infrastructure is continually updated by a GitHub Actions workflow that 
# runs the Terraform code and applies any changes to the infrastructure as needed.

# ---------------------------------------------
# ---- Instantiate Terraform w/ S3 backend ----
# ---------------------------------------------

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
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       # version = "~> 4.0"
#     }
#   }
# }

# terraform {
#   backend "s3" {
#     bucket = var.tfstate_s3_bucket_name,
#     key    = var.tfstate_s3_object_key,
#     region = var.aws_region
#   }
# }

# ---------------------------------------------
# ---- Specify provider (region + profile) ----
# ---------------------------------------------

provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
}

# -------------------------
# ---- Local variables ----
# -------------------------
# - paths to Lambda zip files that get created when deployed 
# - tag variable for naming resources by the project name ("mros")

locals {
  # airtable_lambda_zip = "../deploy/lambda_function.zip"
    mros_airtable_to_sqs_zip      = "../deploy/mros_airtable_to_sqs.zip"
    mros_stage_to_prod_zip        = "../deploy/mros_stage_to_prod.zip"
    mros_append_daily_data_zip    = "../deploy/mros_append_daily_data.zip"
    mros_insert_into_dynamodb_zip = "../deploy/mros_insert_into_dynamodb.zip"
    name_tag = "mros"
}
