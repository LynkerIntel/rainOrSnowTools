#######################
# S3 Policy Documents #
#######################

# # S3 bucket policy (RAW)
# data "aws_iam_policy_document" "s3_bucket_policy_document" {
#   statement {
#     sid = "AllowCurrentAccount"
#     effect = "Allow"

#     principals {
#       type = "AWS"
#       identifiers = ["*"]
#     }

#     actions = [
#       "s3:GetObject",
#       "s3:PutObject",
#       "s3:ListBucket"
#     ]

#     resources = [
#       aws_s3_bucket.airtable_s3_bucket.arn,
#       "${aws_s3_bucket.airtable_s3_bucket.arn}/*"
#     ]

#     condition {
#       test = "StringEquals"
#       variable = "aws:PrincipalAccount"
#       values = [var.aws_account_number]
#     }
#   }
# }

# S3 bucket policy (STAGE)
data "aws_iam_policy_document" "staging_s3_bucket_policy_document" {
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

# s3 bucket policy (PROD)
data "aws_iam_policy_document" "prod_s3_bucket_policy_document" {
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

# s3 bucket policy (PROD)
data "aws_iam_policy_document" "output_s3_bucket_policy_document" {
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
      data.aws_s3_bucket.output_s3_bucket.arn,
      "${data.aws_s3_bucket.output_s3_bucket.arn}/*"
    ]

    condition {
      test = "StringEquals"
      variable = "aws:PrincipalAccount"
      values = [var.aws_account_number]
    }
  }
}


##################################
# Lambda Role (mros_lambda_role) #
##################################

# IAM policy document allowing Lambda to AssumeRole
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
  name_prefix         = "mros_lambda_role"
  assume_role_policy  = data.aws_iam_policy_document.lambda_assume_role.json
  tags = {
    name              = local.name_tag
    resource_category = "iam"
  }
}

############################################################################
# Lambda Role (mros_lambda_role) Attach AWSLambdaBasicExecutionRole Policy #
############################################################################

# Attach necessary policies to the IAM role
resource "aws_iam_role_policy_attachment" "lambda_role_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  # policy_arn = aws_iam_policy.lambda_policy.arn
}

###############################################################
# Lambda Role (mros_lambda_role) Attach S3 permissions Policy #
###############################################################

# # Inline policy for S3 permissions using jsonencode
# resource "aws_iam_policy" "lambda_s3_policy" {
#   name        = "mros_lambda_s3_policy"
#   description = "Policy for Lambda to interact with S3 bucket"

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect   = "Allow",
#         Action   = [
#           "s3:GetObject",
#           "s3:PutObject",
#           "s3:ListBucket"
#           ],
#         Resource = [
#           aws_s3_bucket.airtable_s3_bucket.arn,
#           "${aws_s3_bucket.airtable_s3_bucket.arn}/*",
#           aws_s3_bucket.staging_s3_bucket.arn,
#           "${aws_s3_bucket.staging_s3_bucket.arn}/*",
#           aws_s3_bucket.prod_s3_bucket.arn,
#           "${aws_s3_bucket.prod_s3_bucket.arn}/*",
#         ],
#       },
#     ],
#   })
# }

# # Attach the inline S3 policy to the IAM role
# resource "aws_iam_role_policy_attachment" "lambda_s3_policy_attachment" {
#   role       = aws_iam_role.lambda_role.name
#   policy_arn = aws_iam_policy.lambda_s3_policy.arn
# }

# Inline policy for S3 permissions using jsonencode
data "aws_iam_policy_document" "lambda_s3_policy_doc" {
  statement {
    sid = "MROSLambdaS3ReadAndWritePolicy"
    
    effect = "Allow"

    actions = [
     "s3:GetObject", 
          "s3:PutObject",
          "s3:ListBucket"
    ]

    resources = [
    #   aws_s3_bucket.airtable_s3_bucket.arn,
    #   "${aws_s3_bucket.airtable_s3_bucket.arn}/*",
      
      aws_s3_bucket.staging_s3_bucket.arn,
      "${aws_s3_bucket.staging_s3_bucket.arn}/*",
      
      aws_s3_bucket.prod_s3_bucket.arn,
      "${aws_s3_bucket.prod_s3_bucket.arn}/*",
    ]
    # principals {
    #   type = "AWS"
    #   identifiers = ["*"]
    # }
 
    # condition {
    #   test = "StringEquals"
    #   variable = "aws:PrincipalAccount"
    #   values = [var.aws_account_number]
    # }
  }

   statement {
    sid = "SQSSendMessagePermissions"
    
    effect = "Allow"

    actions = [
          "sqs:SendMessage"
    ]

    resources = [
      aws_sqs_queue.mros_sqs_queue.arn
      ]

    # principals {
    #   type = "AWS"
    #   identifiers = ["*"]
    # }
    #     condition {
    #   test = "StringEquals"
    #   variable = "aws:PrincipalAccount"
    #   values = [var.aws_account_number]
    # }

  }

}

# Make an IAM policy from the IAM policy document for S3/SQS permissions for sqs_consumer lambda
resource "aws_iam_policy" "lambda_s3_policy" {
  name_prefix = "mros-lambda-s3-policy"
  description = "IAM Policy for MROS Lambdas (mros_airtable_to_sqs and mros_stage_to_prod) to interact with S3"
  policy      = data.aws_iam_policy_document.lambda_s3_policy_doc.json
  tags = {
    name              = local.name_tag
    resource_category = "iam"
  }
}

# Attach the inline S3 policy to the IAM role
resource "aws_iam_role_policy_attachment" "lambda_s3_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}


###############################################################
# Lambda Logging Policy (mros-airtable-processor-logging-policy) 
# - Allow Lambda to send logs to CloudWatch Logs #
###############################################################

resource "aws_iam_policy" "logging_policy" {
  name_prefix   = "mros-airtable-processor-logging-policy"
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

# Attach the lambda logging IAM policy to the Python lambda roles
resource "aws_iam_role_policy_attachment" "lambda_logs_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.logging_policy.arn
}

# Attach the lambda logging IAM policy to the R function lambda role
resource "aws_iam_role_policy_attachment" "sqs_consumer_lambda_logs_policy_attachment" {
  role       = aws_iam_role.sqs_consumer_lambda_role.name
  policy_arn = aws_iam_policy.logging_policy.arn
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

##############################
# Lambda Role (sqs_consumer) #
##############################

# lambda role to assume
data "aws_iam_policy_document" "sqs_consumer_lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Create an IAM role for the sqs_consumer lambda to assume role
resource "aws_iam_role" "sqs_consumer_lambda_role" {
  name_prefix               = "mros-sqs-consumer-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.sqs_consumer_lambda_assume_role.json
  tags = {
    name              = local.name_tag
    resource_category = "iam"
  }
}

##############################
# DynamoDB Table permissions #
##############################

# Policy docuemnet for DynamoDB permissions 
data "aws_iam_policy_document" "lambda_dynamodb_policy_doc" {
  statement {
    sid = "LambdaDynamoDBPermissions"
    effect = "Allow"

    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:DescribeTable",
    ]

    resources = [
      aws_dynamodb_table.mros_dynamodb_table.arn,
      "${aws_dynamodb_table.mros_dynamodb_table.arn}/*"
    ]
  }
}

# Make an IAM policy from the IAM policy document for DynamoDB permissions
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name_prefix = "mros-lambda-dynamodb-policy"
  description = "IAM Policy for MROS mros_insert_into_dynamodb Lambda function to interact with DynamoDB"
  policy      = data.aws_iam_policy_document.lambda_dynamodb_policy_doc.json
  tags = {
    name              = local.name_tag
    resource_category = "iam"
  }
}

# Attach the inline DynamoDB policy to the IAM role
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

###################################################
# Lambda (sqs_consumer) IAM Policy for S3/SQS queue
###################################################

data "aws_iam_policy_document" "sqs_consumer_lambda_policy_doc" {
  statement {
    sid = "EnableS3ReadWritePermissions"
    
    effect = "Allow"

    actions = [
     "s3:GetObject", 
          "s3:PutObject",
          "s3:ListBucket"
    ]

    resources = [
    #   aws_s3_bucket.airtable_s3_bucket.arn,
    #   "${aws_s3_bucket.airtable_s3_bucket.arn}/*",
      
      aws_s3_bucket.staging_s3_bucket.arn,
      "${aws_s3_bucket.staging_s3_bucket.arn}/*",
      
      aws_s3_bucket.prod_s3_bucket.arn,
      "${aws_s3_bucket.prod_s3_bucket.arn}/*",
      
      data.aws_s3_bucket.output_s3_bucket.arn,
      "${data.aws_s3_bucket.output_s3_bucket.arn}/*",
    ]
    # principals {
    #   type = "AWS"
    #   identifiers = ["*"]
    # }
 
    # condition {
    #   test = "StringEquals"
    #   variable = "aws:PrincipalAccount"
    #   values = [var.aws_account_number]
    # }
  }

  statement {
    sid = "SQSReadDeletePermissions"
    
    effect = "Allow"

    actions = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
    ]

    resources = [
      aws_sqs_queue.mros_sqs_queue.arn,
      aws_sqs_queue.sqs_stage_queue.arn,
      aws_sqs_queue.sqs_prod_to_output_queue.arn
      ]

    # principals {
    #   type = "AWS"
    #   identifiers = ["*"]
    # }
    #     condition {
    #   test = "StringEquals"
    #   variable = "aws:PrincipalAccount"
    #   values = [var.aws_account_number]
    # }

  }
}

# Make an IAM policy from the IAM policy document for S3/SQS permissions for sqs_consumer lambda
resource "aws_iam_policy" "sqs_consumer_lambda_policy" {
  name        = "mros-sqs-consumer-lambda-policy"
  description = "MROS Policy for sqs consumer Lambda to interact with S3 and SQS queue"
  policy      = data.aws_iam_policy_document.sqs_consumer_lambda_policy_doc.json
  tags = {
    name              = local.name_tag
    resource_category = "iam"
  }
}

# Attach the lambda to SQS IAM policy to the lambda role
resource "aws_iam_role_policy_attachment" "sqs_consumer_lambda_policy_attachment" {
  role       = aws_iam_role.sqs_consumer_lambda_role.name
  policy_arn = aws_iam_policy.sqs_consumer_lambda_policy.arn
  # policy_arn = data.aws_iam_policy_document.sqs_consumer_lambda_policy.json
}


# Attach necessary policies to the IAM role
resource "aws_iam_role_policy_attachment" "sqs_consumer_lambda_basic_exec_policy_attachment" {
  role       = aws_iam_role.sqs_consumer_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  # policy_arn = aws_iam_policy.lambda_policy.arn
}

# # IAM Policy for sqs_consumer Lambda to interact with S3 and SQS queue
# resource "aws_iam_policy" "sqs_consumer_lambda_policy" {
#   name = "mros-sqs-consumer-lambda-policy"
#   # name        = "mros_r_lambda_sqs_policy"
#   description = "MROS Policy for sqs_consumer Lambda to interact with S3 and SQS queue"
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       # S3 permissions
#       {
#         Effect   = "Allow",
#         Action   = [
#           "s3:GetObject", 
#           "s3:PutObject",
#           "s3:ListBucket"
#           ],
#         Resource = [
#           aws_s3_bucket.airtable_s3_bucket.arn,
#           "${aws_s3_bucket.airtable_s3_bucket.arn}/*",
          
#           aws_s3_bucket.staging_s3_bucket.arn,
#           "${aws_s3_bucket.staging_s3_bucket.arn}/*",
          
#           aws_s3_bucket.prod_s3_bucket.arn,
#           "${aws_s3_bucket.prod_s3_bucket.arn}/*",
#         ],
#       },
#       # SQS permissions
#       {
#         Effect   = "Allow",
#         Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"],
#         Resource = aws_sqs_queue.mros_sqs_queue.arn,
#       },
#     ],
#   })
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = [
#           "sqs:ReceiveMessage",
#           "sqs:DeleteMessage",
#           "sqs:GetQueueAttributes",
#         ],
#         Resource = aws_sqs_queue.mros_sqs_queue.arn,
#       },
#     ],
#   })
# }

# # Attach the lambda to SQS IAM policy to the lambda role
# resource "aws_iam_role_policy_attachment" "sqs_consumer_lambda_policy_attachment" {
#   role       = aws_iam_role.sqs_consumer_lambda_role.name
#   policy_arn = aws_iam_policy.sqs_consumer_lambda_policy.arn
# }

# # Lambda Role and Policy for SQS queue
# resource "aws_iam_policy" "r_lambda_sqs_policy" {
#   name        = "mros_r_lambda_sqs_policy"
#   description = "Policy for Lambda to interact with SQS queue"
  
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = [
#           "sqs:ReceiveMessage",
#           "sqs:DeleteMessage",
#           "sqs:GetQueueAttributes",
#         ],
#         Resource = aws_sqs_queue.mros_sqs_queue.arn,
#       },
#     ],
#   })
# }

