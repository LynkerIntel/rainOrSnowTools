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

locals {
  # airtable_lambda_zip = "../deploy/lambda_function.zip"
    airtable_lambda_zip = "../deploy/process_airtable.zip"
    process_staging_zip = "../deploy/process_staging.zip"
}

# ####################
# # SECRETS MANAGERS #
# ####################

resource "aws_secretsmanager_secret" "airtable_secret" {
  name_prefix = var.airtable_secret_prefix
  recovery_window_in_days = 0
  description = "Secrets for MROS Airtable"
}

# AWS Secrets Manager Secret Version for Airtable Secrets
resource "aws_secretsmanager_secret_version" "airtable_secret_version" {
  secret_id     = aws_secretsmanager_secret.airtable_secret.id
  secret_string = jsonencode({
    "AIRTABLE_BASE_ID"     = var.airtable_base_id
    "AIRTABLE_TABLE_ID"    = var.airtable_table_id
    "AIRTABLE_API_TOKEN"   = var.airtable_api_token
  })
}

###########################################
# S3 bucket for rainOrSnowTools R package #
###########################################

# S3 bucket for rainOrSnowTools R package
resource "aws_s3_bucket" "rpkg_bucket" {
  bucket = var.r_pkg_s3_bucket_name
  acl    = "private"
  tags = {
    Name        = "rainorsnowtools"
    Environment = "dev"
  }
}

###############################
# S3 bucket for airtable data #
###############################

# s3 bucket for lambda code
resource "aws_s3_bucket" "airtable_s3_bucket" {
  bucket = var.airtable_s3_bucket_name
}

###############################
# S3 Staging JSON data #
###############################

# s3 bucket for lambda code
resource "aws_s3_bucket" "staging_s3_bucket" {
  bucket = var.staging_s3_bucket_name
}

###############################
# S3 bucket for airtable data #
###############################

# s3 bucket for lambda code
resource "aws_s3_bucket" "prod_s3_bucket" {
  bucket = var.prod_s3_bucket_name
}

#######################################
# S3 bucket permissions airtable data #
#######################################

# s3 bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "airtable_s3_bucket_ownership_controls" {
  bucket = aws_s3_bucket.airtable_s3_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# s3 bucket public access block
resource "aws_s3_bucket_public_access_block" "airtable_s3_public_access_block" {
  bucket = aws_s3_bucket.airtable_s3_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

}

resource "aws_s3_bucket_acl" "airtable_s3_bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.airtable_s3_bucket_ownership_controls,
    aws_s3_bucket_public_access_block.airtable_s3_public_access_block,
  ]

  bucket = aws_s3_bucket.airtable_s3_bucket.id
  acl    = "private"
}

data "aws_iam_policy_document" "s3_bucket_policy_document" {
  statement {
    sid = "AllowCurrentAccount"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.airtable_s3_bucket.arn,
      "${aws_s3_bucket.airtable_s3_bucket.arn}/*"
    ]

    condition {
      test = "StringEquals"
      variable = "aws:PrincipalAccount"
      values = [var.aws_account_number]
    }
  }
}

# s3 bucket policy to allow public access
resource "aws_s3_bucket_policy" "airtable_bucket_policy" {
  bucket = aws_s3_bucket.airtable_s3_bucket.id
  policy = data.aws_iam_policy_document.s3_bucket_policy_document.json
  depends_on = [
    aws_s3_bucket_acl.airtable_s3_bucket_acl,
    aws_s3_bucket_ownership_controls.airtable_s3_bucket_ownership_controls,
    aws_s3_bucket_public_access_block.airtable_s3_public_access_block,
  ]
}
#################################
# Staging S3 bucket permissions #
#################################

# s3 bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "staging_s3_bucket_ownership_controls" {
  bucket = aws_s3_bucket.staging_s3_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# s3 bucket public access block
resource "aws_s3_bucket_public_access_block" "staging_s3_public_access_block" {
  bucket = aws_s3_bucket.staging_s3_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

}

resource "aws_s3_bucket_acl" "staging_s3_bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.staging_s3_bucket_ownership_controls,
    aws_s3_bucket_public_access_block.staging_s3_public_access_block,
  ]

  bucket = aws_s3_bucket.staging_s3_bucket.id
  acl    = "private"
}

data "aws_iam_policy_document" "s3_bucket_policy_document" {
  statement {
    sid = "AllowCurrentAccount"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.staging_s3_bucket.arn,
      "${aws_s3_bucket.staging_s3_bucket.arn}/*"
    ]

    condition {
      test = "StringEquals"
      variable = "aws:PrincipalAccount"
      values = [var.aws_account_number]
    }
  }
}

# s3 bucket policy to allow public access
resource "aws_s3_bucket_policy" "staging_bucket_policy" {
  bucket = aws_s3_bucket.staging_s3_bucket.id
  policy = data.aws_iam_policy_document.s3_bucket_policy_document.json
  depends_on = [
    aws_s3_bucket_acl.staging_s3_bucket_acl,
    aws_s3_bucket_ownership_controls.staging_s3_bucket_ownership_controls,
    aws_s3_bucket_public_access_block.staging_s3_public_access_block,
  ]
}


#################################
# Staging S3 bucket permissions #
#################################

# s3 bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "prod_s3_bucket_ownership_controls" {
  bucket = aws_s3_bucket.prod_s3_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# s3 bucket public access block
resource "aws_s3_bucket_public_access_block" "prod_s3_public_access_block" {
  bucket = aws_s3_bucket.prod_s3_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

}

resource "aws_s3_bucket_acl" "prod_s3_bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.prod_s3_bucket_ownership_controls,
    aws_s3_bucket_public_access_block.prod_s3_public_access_block,
  ]

  bucket = aws_s3_bucket.prod_s3_bucket.id
  acl    = "private"
}

data "aws_iam_policy_document" "s3_bucket_policy_document" {
  statement {
    sid = "AllowCurrentAccount"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.prod_s3_bucket.arn,
      "${aws_s3_bucket.prod_s3_bucket.arn}/*"
    ]

    condition {
      test = "StringEquals"
      variable = "aws:PrincipalAccount"
      values = [var.aws_account_number]
    }
  }
}

# s3 bucket policy to allow public access
resource "aws_s3_bucket_policy" "prod_bucket_policy" {
  bucket = aws_s3_bucket.prod_s3_bucket.id
  policy = data.aws_iam_policy_document.s3_bucket_policy_document.json
  depends_on = [
    aws_s3_bucket_acl.prod_s3_bucket_acl,
    aws_s3_bucket_ownership_controls.prod_s3_bucket_ownership_controls,
    aws_s3_bucket_public_access_block.prod_s3_public_access_block,
  ]
}
####################################
# Upload Lambda function zips to S3 #
####################################

# s3 bucket for lambda code
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = var.lambda_bucket_name
}

# s3 object for lambda code for process_airtable function
resource "aws_s3_object" "airtable_lambda_code_object" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = var.airtable_lambda_zip_file_name
  source = local.airtable_lambda_zip
}

# s3 object for lambda code process_staging function
resource "aws_s3_object" "staging_lambda_code_object" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = var.process_staging_lambda_zip_file_name
  source = local.process_staging_zip
}

##########################
# Lambda Role and Policy #
##########################

# lambda role to assume
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Create an IAM role for the lambda to assume role
resource "aws_iam_role" "lambda_role" {
  name               = "mros_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Attach necessary policies to the IAM role
resource "aws_iam_role_policy_attachment" "lambda_role_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  # policy_arn = aws_iam_policy.lambda_policy.arn
}

###############################
# Lambda Log Group (Airtable) #
###############################

# lambda log group
resource "aws_cloudwatch_log_group" "airtable_lambda_log_group" {
  name              = "/aws/lambda/${var.airtable_lambda_function_name}"
  retention_in_days = 14
}

resource "aws_iam_policy" "logging_policy" {
  name   = "mros-airtable-processor-logging-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect : "Allow",
        Resource : "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Attach the lambda logging IAM policy to the lambda role
resource "aws_iam_role_policy_attachment" "lambda_logs_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.logging_policy.arn
}

###############################
# Lambda Log Group (Staging) #
###############################

# lambda log group
resource "aws_cloudwatch_log_group" "staging_lambda_log_group" {
  name              = "/aws/lambda/${var.process_staging_lambda_function_name}"
  retention_in_days = 14
}

# resource "aws_iam_policy" "logging_policy" {
#   name   = "mros-staging-processor-logging-policy"
#   policy = jsonencode({
#     "Version" : "2012-10-17",
#     "Statement" : [
#       {
#         Action : [
#           "logs:CreateLogGroup",
#           "logs:CreateLogStream",
#           "logs:PutLogEvents"
#         ],
#         Effect : "Allow",
#         Resource : "arn:aws:logs:*:*:*"
#       }
#     ]
#   })
# }

# # Attach the lambda logging IAM policy to the lambda role
# resource "aws_iam_role_policy_attachment" "lambda_logs_policy_attachment" {
#   role       = aws_iam_role.lambda_role.name
#   policy_arn = aws_iam_policy.logging_policy.arn
# }

####################################
# Lambda Function (Airtable to S3) #
####################################

# lambda function to process csv file
resource "aws_lambda_function" "airtable_lambda_function" {
  s3_bucket        = aws_s3_bucket.lambda_bucket.bucket
  s3_key           = var.airtable_lambda_zip_file_name
  function_name    = var.airtable_lambda_function_name
  handler          = "process_airtable.process_airtable.process_airtable"
  # handler          = "function.name/handler.process_csv_lambda"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.11"
  architectures    = ["x86_64"]
  # architectures    = ["arm64"]

  # Attach the Lambda function to the CloudWatch Logs group
  environment {
    variables = {
        CW_LOG_GROUP = aws_cloudwatch_log_group.airtable_lambda_log_group.name,
        BASE_ID = var.airtable_base_id,
        TABLE_ID = var.airtable_table_id,
        AIRTABLE_TOKEN = var.airtable_api_token,
        S3_BUCKET = "s3://${aws_s3_bucket.airtable_s3_bucket.bucket}",
        # S3_BUCKET = var.airtable_s3_bucket_name,
        # DYNAMODB_TABLE = aws_dynamodb_table.airtable_dynamodb_table.name,
        SQS_QUEUE_URL = aws_sqs_queue.mros_sqs_queue.url
    }
  }

  # timeout in seconds
  timeout         = 300
  
  depends_on = [
    aws_s3_bucket.lambda_bucket,
    aws_s3_object.airtable_lambda_code_object,
    aws_iam_role_policy_attachment.lambda_logs_policy_attachment,
    aws_cloudwatch_log_group.airtable_lambda_log_group,
    # aws_dynamodb_table.mros_dynamodb_table,
    aws_sqs_queue.mros_sqs_queue,
  ]

}

# resource "aws_lambda_permission" "lambda_put_to_s3_permission" {
#   statement_id  = "AllowExecutionFromS3"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.airtable_lambda_function.function_name
#   principal     = "s3.amazonaws.com"
#   source_arn    = aws_s3_bucket.airtable_s3_bucket.arn
# }

####################################
# Lambda Function (Staging to S3) #
####################################
# S3_BUCKET
# S3_STAGING_BUCKET
# S3_PROD_BUCKET
# S3_STAGING_BUCKET_NAME
# S3_PROD_BUCKET_NAME

# lambda function to process csv file
resource "aws_lambda_function" "staging_lambda_function" {
  s3_bucket        = aws_s3_bucket.lambda_bucket.bucket
  s3_key           = var.process_staging_lambda_zip_file_name
  function_name    = var.process_staging_lambda_function_name
  handler          = "process_staging_bucket.process_staging_bucket.process_staging_bucket"
  # handler          = "function.name/handler.process_csv_lambda"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.11"
  architectures    = ["x86_64"]
  # architectures    = ["arm64"]

  # Attach the Lambda function to the CloudWatch Logs group
  environment {
    variables = {
        CW_LOG_GROUP = aws_cloudwatch_log_group.staging_lambda_log_group.name,
        S3_BUCKET = "s3://${aws_s3_bucket.staging_s3_bucket.bucket}",
        S3_STAGING_BUCKET = "s3://${aws_s3_bucket.staging_s3_bucket.bucket}",
        S3_PROD_BUCKET = "s3://${aws_s3_bucket.prod_s3_bucket.bucket}",
        S3_STAGING_BUCKET_NAME = aws_s3_bucket.staging_s3_bucket.bucket,
        S3_PROD_BUCKET_NAME = aws_s3_bucket.prod_s3_bucket.bucket
        # DYNAMODB_TABLE = aws_dynamodb_table.airtable_dynamodb_table.name,
        # SQS_QUEUE_URL = aws_sqs_queue.mros_sqs_queue.url
    }
  }

  # timeout in seconds
  timeout         = 300
  
  depends_on = [
    aws_s3_bucket.lambda_bucket,
    aws_s3_object.staging_lambda_code_object,
    aws_iam_role_policy_attachment.lambda_logs_policy_attachment,
    aws_cloudwatch_log_group.staging_lambda_log_group,
    # aws_dynamodb_table.mros_dynamodb_table,
    aws_sqs_queue.mros_sqs_queue,
  ]

}

# resource "aws_lambda_permission" "lambda_put_to_s3_permission" {
#   statement_id  = "AllowExecutionFromS3"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.airtable_lambda_function.function_name
#   principal     = "s3.amazonaws.com"
#   source_arn    = aws_s3_bucket.airtable_s3_bucket.arn
# }
#####################################
# EventBridge Rule for Lambda Event #
#####################################

# EventBridge rule to trigger lambda function
resource "aws_cloudwatch_event_rule" "airtable_event_rule" {
  name                = "airtable_event_rule"
  description         = "Event rule to trigger lambda function"
  schedule_expression = "rate(2 minutes)"
}

# EventBridge target for lambda function
resource "aws_cloudwatch_event_target" "airtable_event_target" {
  rule      = aws_cloudwatch_event_rule.airtable_event_rule.name
  target_id = "airtable_event_target"
  arn       = aws_lambda_function.airtable_lambda_function.arn
} 

resource "aws_lambda_permission" "cloudwatch_invoke_lambda_permission" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.airtable_lambda_function.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.airtable_event_rule.arn
}

#########################################
# SQS queue for Lambda to put data into #
#########################################

# SQS queue for lambda to put data into 
resource "aws_sqs_queue" "mros_sqs_queue" {
  name                       = var.sqs_queue_name
  message_retention_seconds  = 86400  # 1 day retention
  visibility_timeout_seconds = 300   # 5 min visibility timeout
}

# ####################################################################
# # DynamoDB Table to store data from Airtable (via Lambda function) #
# ####################################################################

# resource "aws_dynamodb_table" "mros_dynamodb_table" {
#   name           = var.dynamodb_table_name
#   billing_mode   = "PAY_PER_REQUEST"
#   hash_key       = "id"
#   attribute {
#     name = "id"
#     type = "S"
#   }
# }

# # DynamoDB table policy to allow lambda to write to table
# resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
#   name   = "lambda_dynamodb_policy"
#   role   = aws_iam_role.lambda_role.name

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = [
#           "dynamodb:PutItem",
#           "dynamodb:UpdateItem",
#           "dynamodb:BatchWriteItem",
#         ],
#         Resource = aws_dynamodb_table.mros_dynamodb_table.arn,
#       },
#     ],
#   })
# }

# # Attach the lambda to DynamoDB IAM policy to the lambda role
# resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy_attachment" {
#   role       = aws_iam_role.lambda_role.name
#   policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
# }
