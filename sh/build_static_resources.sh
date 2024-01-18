#!/bin/bash

# Create a ECR repository for use by the infrastructure created by Terraform (e.g. Docker images). 
# This script is run before terraform plan/apply to ensure that the ECR repository exist before
# terraform tries to use the Docker Image to create the Lambda function.

# Provide AWS Account Number as first argument
# Example: source sh/build_static_resources.sh 123456789

# AWS Account Number
AWS_ACCOUNT_NUMBER=$1

# AWS Profile
AWS_PROFILE=$2

# S3 bucket
BUCKET_NAME=$3
BUCKET_NAME="mros-output-bucket"

# S3 object key and CSV file content
S3_OBJECT_KEY="mros_output.csv"
CSV_CONTENT="date,id,value,lat,lng"

# ECR repo names
ECR_REPO_NAME="mros-sqs-consumer-lambda-ecr"

# regions to create/check resources
AWS_REGION="us-west-1"
LOCATION_CONSTRAINT="us-west-1"

# Export ECR repo name as variable for Terraform
export TF_VAR_output_s3_bucket_name="$BUCKET_NAME"
export TF_VAR_output_s3_object_key="$S3_OBJECT_KEY"
export TF_VAR_sqs_consumer_ecr_repo_name="$ECR_REPO_NAME"

# check if the output bucket ALREADY EXISTS
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE" 2>/dev/null; then
    # Create the output bucket if it DOESN'T exist
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION"  --profile "$AWS_PROFILE" --create-bucket-configuration LocationConstraint="$LOCATION_CONSTRAINT"
else
    echo "Bucket $BUCKET_NAME already exists."
fi

# Upload empty CSV file if it does NOT already exist
if ! aws s3api head-object --bucket "$BUCKET_NAME" --key "$S3_OBJECT_KEY" --region "$AWS_REGION" --profile "$AWS_PROFILE" 2>/dev/null; then
    # Create an empty CSV file
    echo "$CSV_CONTENT" | aws s3 cp - s3://"$BUCKET_NAME"/"$S3_OBJECT_KEY" --region "$AWS_REGION" --profile "$AWS_PROFILE"
    echo "Empty CSV file uploaded to S3: $BUCKET_NAME/$S3_OBJECT_KEY"
else
    echo "CSV file $S3_OBJECT_KEY already exists in S3 bucket $BUCKET_NAME."
fi

# check if the ECR repository ALREADY EXISTS
if ! aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" 2>/dev/null; then
    # create the ECR repository if it DOESN'T exist
    aws ecr create-repository --repository-name "$ECR_REPO_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE"
    echo "ECR repository $ECR_REPO_NAME created."
else
    echo "ECR repository $ECR_REPO_NAME already exists."
fi

# Get the ECR repository URL
ECR_REPO_URL=$(aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" --query 'repositories[0].repositoryUri' --output text)

# export ECR repository URL as Terraform variable
export TF_VAR_sqs_consumer_ecr_repo_url="$ECR_REPO_URL"

echo "ECR repository URL: $ECR_REPO_URL"

# Determine the current operating system
OS=$(uname -s)

# print the operating system
echo "Operating system: $OS"

# AWS CLI and Docker commands to login, build, tag, and push Docker image
aws ecr get-login-password --region "$AWS_REGION" --profile "$AWS_PROFILE" | docker login --username AWS --password-stdin $AWS_ACCOUNT_NUMBER.dkr.ecr.$AWS_REGION.amazonaws.com


# If the operating system is macOS, update the platform
if [ "$OS" = "Darwin" ]; then
  PLATFORM="linux/amd64"
  
  echo "Building Docker image with --platform $PLATFORM flag"

  # build Docker image
  docker build -t mros-sqs-consumer-lambda-ecr --platform $PLATFORM lambda_containers/sqs_consumer/
#   docker build -t $ECR_REPO_NAME --platform $PLATFORM lambda_containers/sqs_consumer/
else
  echo "Building Docker image with no --platform flag"
  # For other operating systems, you can set a default platform or handle it as needed
  # Here, we're setting it to the default platform for Linux
  # build Docker image
  docker build -t mros-sqs-consumer-lambda-ecr lambda_containers/sqs_consumer/
#   docker build -t $ECR_REPO_NAME lambda_containers/sqs_consumer/
fi

# # build Docker image
# docker build -t $ECR_REPO_NAME --platform linux/amd64 lambda_containers/sqs_consumer/

# tag Docker image
docker tag mros-sqs-consumer-lambda-ecr:latest "$AWS_ACCOUNT_NUMBER.dkr.ecr.$AWS_REGION.amazonaws.com/mros-sqs-consumer-lambda-ecr:latest"
# docker tag $ECR_REPO_NAME:latest "$AWS_ACCOUNT_NUMBER.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:latest"

# push Docker image to ECR repository
docker push "$AWS_ACCOUNT_NUMBER.dkr.ecr.$AWS_REGION.amazonaws.com/mros-sqs-consumer-lambda-ecr:latest"