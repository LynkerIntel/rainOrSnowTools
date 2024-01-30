#!/bin/bash

# Create a ECR repository if it one by the given name does NOT already exist. 
# Then build and push a Docker image to the ECR repo

# Provide AWS Account Number, S3 bucket name, Terraform state S3 bucket name, ECR repo name, AWS region, and AWS profile as arguments to the script.
# Example: source sh/build_static_resources.sh 123456789 ecr-repo-name aws-region aws-profile

# AWS Account Number
AWS_ACCOUNT_NUMBER=$1

# ECR repo names 
ECR_REPO_NAME=$2

# AWS Region to create/check resources, if not given, use "us-west-1"
AWS_REGION=${3:-"us-west-1"}
LOCATION_CONSTRAINT=${AWS_REGION}

# AWS Profile, if not given, use "default"
AWS_PROFILE=${4:-"default"}

echo "- ECR_REPO_NAME: $ECR_REPO_NAME"
echo "- AWS_REGION: $AWS_REGION"
echo "- LOCATION_CONSTRAINT: $LOCATION_CONSTRAINT"
echo "- AWS_PROFILE: $AWS_PROFILE"

# -----------------------------------------------------------------------------------------------
# ----- Create ECR repository for Lambda Docker images (if does NOT exist) -----
# -----------------------------------------------------------------------------------------------

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
export TF_VAR_mros_ecr_repo_url="$ECR_REPO_URL"

echo "ECR repository URL: $ECR_REPO_URL"

# -----------------------------------------------------------------------------------------------
# ----- Build and push Docker image to ECR Repo  -----
# -----------------------------------------------------------------------------------------------

# Determine the current operating system
OS=$(uname -s)

# print the operating system
echo "Operating system: $OS"cd 

# AWS CLI and Docker commands to login, build, tag, and push Docker image
aws ecr get-login-password --region "$AWS_REGION" --profile "$AWS_PROFILE" | docker login --username AWS --password-stdin $AWS_ACCOUNT_NUMBER.dkr.ecr.$AWS_REGION.amazonaws.com

# If the operating system is macOS, update the platform
if [ "$OS" = "Darwin" ]; then
  PLATFORM="linux/amd64"
  
  echo "Building Docker image with --platform $PLATFORM flag"

  # build Docker image
  docker build -t mros-sqs-consumer-lambda-ecr --platform $PLATFORM lambda_containers/add_climate_data/
#   docker build -t $ECR_REPO_NAME --platform $PLATFORM lambda_containers/add_climate_data/
else
  echo "Building Docker image with no --platform flag"
  # For other operating systems, you can set a default platform or handle it as needed
  # Here, we're setting it to the default platform for Linux
  # build Docker image
  docker build -t mros-sqs-consumer-lambda-ecr lambda_containers/add_climate_data/
#   docker build -t $ECR_REPO_NAME lambda_containers/add_climate_data/
fi

# # build Docker image
# docker build -t $ECR_REPO_NAME --platform linux/amd64 lambda_containers/add_climate_data/

# tag Docker image
docker tag mros-sqs-consumer-lambda-ecr:latest "$AWS_ACCOUNT_NUMBER.dkr.ecr.$AWS_REGION.amazonaws.com/mros-sqs-consumer-lambda-ecr:latest"
# docker tag $ECR_REPO_NAME:latest "$AWS_ACCOUNT_NUMBER.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:latest"

# push Docker image to ECR repository
docker push "$AWS_ACCOUNT_NUMBER.dkr.ecr.$AWS_REGION.amazonaws.com/mros-sqs-consumer-lambda-ecr:latest"