# # -------------------------------------------------------------------------------
# # ---- UNCOMMENT THIS FILE TO USE this file as a VARIABLES TEMPLATE ----
# # ---- These are the variables that are used in this Terraform configuration ----
# # -------------------------------------------------------------------------------

# # AWS profile to use for AWS CLI.
# variable "aws_profile" {
#   description = "Profile to use for AWS CLI."
#   type        = string
# }

# # # AWS region to use for AWS CLI.
# variable "aws_account_number" {
#   description = "Account number."
#   type        = string
#   sensitive   = true
# }

# # # AWS region to use for AWS CLI.
# variable "aws_region" {
#   description = "Region to use for AWS CLI."
#   type        = string
# }

# variable "airtable_secret_prefix" {
#   description = "prefix string for MROS Airtable secret"
#   type        = string
#   sensitive   = true
# }

# variable "airtable_base_id" {
#   description = "Airtable base ID prefix."
#   type        = string
#   sensitive   = true
# }

# variable "airtable_table_id" {
#   description = "Airtable table ID prefix."
#   type        = string
#   sensitive   = true
# }

# variable "airtable_api_token" {
#   description = "Airtable API Token."
#   type        = string
#   sensitive   = true
# }

# # -----------------------------------
# # ---- Lambda function variables ----
# # -----------------------------------

# variable "airtable_to_sqs_lambda_zip_file_name" {
#     description = "Name of the Lambda zip file."
#     type        = string
#     sensitive   = true
# }

# variable "airtable_to_sqs_lambda_function_name" {
#     description = "Name of the Lambda function."
#     type        = string
#     sensitive   = true
# }

# variable "stage_s3_to_prod_s3_lambda_zip_file_name" {
#     description = "Name of the Lambda zip file."
#     type        = string
#     sensitive   = true
# }

# variable "stage_s3_to_prod_s3_lambda_function_name" {
#     description = "Name of the Lambda function."
#     type        = string
#     sensitive   = true
# }

# variable "sqs_consumer_lambda_function_name" {
#     description = "Name of the Lambda function."
#     type        = string
#     sensitive   = true
# }

# variable "mros_append_daily_data_lambda_zip_file_name" {
#     description = "Name of the Daily data append Lambda zip file."
#     type        = string
#     sensitive   = true
# }

# variable "mros_append_daily_data_lambda_function_name" {
#     description = "Name of the Daily data append Lambda function."
#     type        = string
#     sensitive   = true
# }

# variable "insert_into_dynamodb_lambda_zip_file_name" {
#     description = "Name of the zip file thats contains the lambda function that inserts MROS data into DynamoDB."
#     type        = string
#     sensitive   = true
# }

# variable "insert_into_dynamodb_lambda_function_name" {
#     description = "Name of the Lambda function that inserts MROS data into DynamoDB."
#     type        = string
#     sensitive   = true
# }

# # -----------------------------
# # ---- DynamoDB  variables ----
# # -----------------------------

# variable "dynamodb_table_name" {
#     description = "Name of the DynamoDB table to store the MROS Airtable data."
#     type        = string
#     sensitive   = true
# }

# # -----------------------
# # ---- SQS variables ----
# # -----------------------

# variable "sqs_queue_name" {
#     description = "Name of the SQS queue to store the MROS Airtable data."
#     type        = string
#     sensitive   = true
# }
# variable "sqs_stage_queue_name" {
#     description = "Name of the SQS queue that takes S3 event notifications when a new JSON is uploaded to the MROS staging S3 Bucket and sends them to the output S3 bucket via SQS message."
#     type        = string
#     sensitive   = true
# }

# variable "sqs_prod_to_output_queue_name" {
#     description = "Name of the SQS queue that takes S3 event notifications and sends them to the output S3 bucket via SQS message."
#     type        = string
#     sensitive   = true
# }

# # -----------------------------
# # ---- S3 bucket variables ----
# # -----------------------------

# variable "lambda_bucket_name" {
#     description = "Name of the S3 bucket to store the Lambda code."
#     type        = string
#     sensitive   = true
# }

# variable "airtable_s3_bucket_name" {
#     description = "Name of the S3 bucket to store the Airtable data."
#     type        = string
#     sensitive   = true
# }

# variable "staging_s3_bucket_name" {
#     description = "Name of the S3 bucket to store the staging data."
#     type        = string
#     sensitive   = true
# }

# variable "prod_s3_bucket_name" {
#     description = "Name of the S3 bucket to store the production data."
#     type        = string
#     sensitive   = true
# }

# # -----------------------------------------
# # ---- NASA Data credentials variables ----
# # -----------------------------------------

# # nasa data (EarthData) user environment variable to pass to R lambda function
# variable "nasa_data_user_env_var" {
#     description = "Name of the Lambda function."
#     type        = string
#     sensitive   = true
# }

# # nasa data (EarthData) password environment variable to pass to R lambda function
# variable "nasa_data_password_env_var" {
#     description = "Name of the Lambda function."
#     type        = string
#     sensitive   = true
# }

# # ----------------------------
# # ---- SQS variables ----
# # ----------------------------

# variable "mros_ecr_repo_name" {
#     description = "Name of the ECR repo to store the Docker image."
#     type        = string
# }

# variable "mros_ecr_repo_url" {
#     description = "URL of the ECR repo to store the Docker image"
#     type        = string
# }

# # ----------------------------
# # ---- SNS variables ----
# # ----------------------------

# variable "sns_output_data_topic" {
#     description = "Name of the SNS topic to send the final output data from the S3 event notification."
#     type        = string
# }
# # -------------------------------
# # ---- EventBridge variables ----
# # -------------------------------

# variable "eventbridge_cron_rule_name" {
#     description = "Name of the EventBridge cron rule to trigger the Lambda function that kicksoff daily processing workflow."
#     type        = string 
# }
# # ---------------------------------------------------------------
# # ------------- S3 Bucket (FINAL OUTPUT CSV) variables ----------
# # ---- values are exported from sh/build_static_resources.sh ----
# # ---------------------------------------------------------------

# variable "output_s3_bucket_name" {
#     description = "Name of the S3 bucket to store the final output CSV file"
#     type        = string
# }

# variable "output_s3_object_key" {
#     description = "Name of the S3 object key of the final output CSV file"
#     type        = string
# }

# # # -------------------------------------------------------------------------------------------------------------------------------
# # # ------------------------------------------ S3 Bucket (TF State S3 bucket) variables -------------------------------------------
# # # ---- name of the S3 bucket that contains the S3 backend Terraform state files (exported from sh/build_static_resources.sh) ----
# # # -------------------------------------------------------------------------------------------------------------------------------

# # Terraform state file S3 bucket name
# variable "tfstate_s3_bucket_name" {
#     description = "Name of the S3 bucket to store the Terraform state files to use S3 as a terraform backend"
#     type        = string
# }

# # # Terraform state file name
# variable "tfstate_s3_object_key" {
#     description = "Name of the S3 object key of the Terraform state files to use S3 as a terraform backend"
#     type        = string
# }