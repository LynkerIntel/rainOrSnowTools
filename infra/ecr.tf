
#################################################
# ECR Repo for R Docker image for Lambda Function
#################################################

# ECR Repo for R Docker image for Lambda Function
data "aws_ecr_repository" "r_ecr_repository" {
  name = var.sqs_consumer_ecr_repo_name
}

# # Create ECR repository for R Docker image for Lambda Function
# resource "aws_ecr_repository" "r_ecr_repository" {
#   name = var.sqs_consumer_ecr_repo_name
# }
