# ##################################################################################
# # DynamoDB Table to store data from PROD S3 bucket #
# (via Lambda function that gets triggered by an SNS topic w/ event notifications) #
# ##################################################################################

resource "aws_dynamodb_table" "mros_dynamodb_table" {
  name           = var.dynamodb_table_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "user"
  range_key      = "timestamp"
  
  # set hash key to user
  attribute {
    name = "user"
    type = "S"
  }

  # set range key to timestamp  
  attribute {
    name = "timestamp"
    type = "N"
  }
  
  # create a global secondary index for state and timestamp
  global_secondary_index {
    name               = "state-timestamp-index"
    hash_key           = "state"
    range_key          = "timestamp"
    projection_type    = "ALL"
  }

}

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

# ##############################
# # DynamoDB Table permissions #
# ##############################

# # Policy docuemnet for DynamoDB permissions 
# data "aws_iam_policy_document" "lambda_dynamodb_policy_doc" {
#   statement {
#     sid = "LambdaDynamoDBPermissions"
#     effect = "Allow"

#     actions = [
#       "dynamodb:GetItem",
#       "dynamodb:PutItem",
#       "dynamodb:UpdateItem",
#       "dynamodb:BatchWriteItem",
#       "dynamodb:Query",
#       "dynamodb:Scan",
#     ]

#     resources = [
#       aws_dynamodb_table.mros_dynamodb_table.arn,
#       "${aws_dynamodb_table.mros_dynamodb_table.arn}/*"
#     ]
#   }
# }

# # Make an IAM policy from the IAM policy document for DynamoDB permissions
# resource "aws_iam_policy" "lambda_dynamodb_policy" {
#   name_prefix = "mros-lambda-dynamodb-policy"
#   description = "IAM Policy for MROS mros_insert_into_dynamodb Lambda function to interact with DynamoDB"
#   policy      = data.aws_iam_policy_document.lambda_dynamodb_policy_doc.json
#   tags = {
#     name              = local.name_tag
#     resource_category = "iam"
#   }
# }

# # Attach the inline DynamoDB policy to the IAM role
# resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy_attachment" {
#   role       = aws_iam_role.lambda_role.name
#   policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
# }

# data "aws_iam_policy_document" "sqs_consumer_lambda_s3_policy" {
#   statement {
#     sid = "Enable S3 Read/Write Permissions"
    
#     effect = "Allow"

#     actions = [
#      "s3:GetObject", 
#           "s3:PutObject",
#           "s3:ListBucket"
#     ]

#     resources = [
#       aws_s3_bucket.airtable_s3_bucket.arn,
#       "${aws_s3_bucket.airtable_s3_bucket.arn}/*",
      
#       aws_s3_bucket.staging_s3_bucket.arn,
#       "${aws_s3_bucket.staging_s3_bucket.arn}/*",
      
#       aws_s3_bucket.prod_s3_bucket.arn,
#       "${aws_s3_bucket.prod_s3_bucket.arn}/*",
#     ]
#     principals {
#       type = "AWS"
#       identifiers = ["*"]
#     }
 
#     # condition {
#     #   test = "StringEquals"
#     #   variable = "aws:PrincipalAccount"
#     #   values = [var.aws_account_number]
#     # }
#   }
# }

# data "aws_iam_policy_document" "sqs_consumer_lambda_sqs_policy" {
#   statement {
#     sid = "SQS Read/Delete Permissions"
    
#     effect = "Allow"

#     actions = [
#           "sqs:ReceiveMessage",
#           "sqs:DeleteMessage",
#           "sqs:GetQueueAttributes",
#     ]

#     resources = [
#       aws_sqs_queue.mros_sqs_queue.arn
#       ]

#     principals {
#       type = "AWS"
#       identifiers = ["*"]
#     }

#   }
# }
# resource "aws_iam_policy" "policy" {
#   name        = "test-policy"
#   description = "A test policy"
#   policy      = data.aws_iam_policy_document.policy.json
# }