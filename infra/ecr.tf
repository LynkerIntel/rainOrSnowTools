
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
#################################################
# ECR Docker image data source
#################################################

data "aws_ecr_image" "repo_image" {
  repository_name = var.sqs_consumer_ecr_repo_name
  most_recent       = true
}

###########
# OUTPUTS #
###########

# Output the ECR image ID
output "aws_ecr_image_id" {
  value = data.aws_ecr_image.repo_image.id
}

# Output the image URI
output "aws_ecr_image_tags" {
  value = data.aws_ecr_image.repo_image.image_tags
}

# Output the image URI
output "aws_ecr_image_pushed_at" {
  value = data.aws_ecr_image.repo_image.image_pushed_at
}