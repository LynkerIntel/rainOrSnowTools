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