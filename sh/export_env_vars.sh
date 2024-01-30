#!/bin/bash

# Export all of the environment variables needed for the Terraform configuration
# # Provide AWS Profile as an argument to the script, if not given, use "default"
# Provide ECR repo tag as an argument to the script, if not given, use "latest"
# Provide RUNNING_ON_GITHUB_ACTION as an argument to the script, if not given, use "false"
# Github Actions will provide Github SHA as ECR repo tag for the Docker image

# Example: source sh/export_env_vars.sh ecr-repo-tag false

# # AWS Profile, if not given, use "default"
# AWS_PROFILE=${1:-"default"}

# Provided ECR repo tag and if not given, use "latest"
ECR_REPO_TAG=${1:-"latest"}

# Flag to determine whether to export variables to $GITHUB_ENV
RUNNING_ON_GITHUB_ACTION=${2:-"false"}

# # Export the AWS profile as a Terraform variable
# export "TF_VAR_aws_profile"="$AWS_PROFILE"

# Export ECR image tag as Terraform variable
export "TF_VAR_mros_ecr_image_tag"="$ECR_REPO_TAG"

# Lambda function names
export "TF_VAR_mros_add_climate_data_lambda_function_name"="mros-add-climate-data"

# DynamoDB table name
export "TF_VAR_dynamodb_table_name"="mros-observations-table"

# SQS queue names
export "TF_VAR_sqs_queue_name"="mros-observations-queue"
export "TF_VAR_sqs_stage_queue_name"="mros-stage-queue"
export "TF_VAR_sqs_prod_to_output_queue_name"="mros-prod-to-output-queue"

# S3 bucket names
export "TF_VAR_lambda_bucket_name"="mros-lambda-bucket"
export "TF_VAR_staging_s3_bucket_name"="mros-staging-bucket"
export "TF_VAR_prod_s3_bucket_name"="mros-prod-bucket" 

# SNS topic name
export "TF_VAR_sns_output_data_topic"="mros-output-data-sns-topic"

# EventBridge rule name
export "TF_VAR_eventbridge_cron_rule_name"="mros_airtable_event_rule"

# Check if the script is running on GitHub Actions (RUNNING_ON_GITHUB_ACTION=true), if so
# then export the environment variables to $GITHUB_ENV so they are made available to
# the next steps in the workflow
if [[ "$RUNNING_ON_GITHUB_ACTION" == "true" ]]; then

    echo "Running on GitHub Actions, exporting environment variables to Github Env..."

    # # Export the environment variables to $GITHUB_ENV
    # # AWS Profile
    # echo "TF_VAR_aws_profile=$AWS_PROFILE" >> $GITHUB_ENV

    # ECR image tag
    echo "TF_VAR_mros_ecr_image_tag=$ECR_REPO_TAG" >> $GITHUB_ENV

    # Lambda function names
    echo "TF_VAR_mros_add_climate_data_lambda_function_name=mros-add-climate-data" >> $GITHUB_ENV
    
    # DynamoDB table name
    echo "TF_VAR_dynamodb_table_name=mros-observations-table" >> $GITHUB_ENV

    # SQS queue names
    echo "TF_VAR_sqs_queue_name=mros-observations-queue" >> $GITHUB_ENV
    echo "TF_VAR_sqs_stage_queue_name=mros-stage-queue" >> $GITHUB_ENV
    echo "TF_VAR_sqs_prod_to_output_queue_name=mros-prod-to-output-queue" >> $GITHUB_ENV

    # S3 bucket names
    echo "TF_VAR_lambda_bucket_name=mros-lambda-bucket" >> $GITHUB_ENV
    echo "TF_VAR_staging_s3_bucket_name=mros-staging-bucket" >> $GITHUB_ENV
    echo "TF_VAR_prod_s3_bucket_name=mros-prod-bucket" >> $GITHUB_ENV

    # SNS topic name
    echo "TF_VAR_sns_output_data_topic=mros-output-data-sns-topic" >> $GITHUB_ENV

    # EventBridge rule name
    echo "TF_VAR_eventbridge_cron_rule_name=mros_airtable_event_rule" >> $GITHUB_ENV
fi