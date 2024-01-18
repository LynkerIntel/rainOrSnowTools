#########################################
# SQS queue for Lambda to put data into #
#########################################

# SQS queue for lambda to put data into 
resource "aws_sqs_queue" "mros_sqs_queue" {
  name                       = var.sqs_queue_name
  # message_retention_seconds  = 86400  # 1 day retention
  # visibility_timeout_seconds = 300   # 5 min visibility timeout
  delay_seconds             = 90
  max_message_size          = 2048
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
  # visibility_timeout_seconds = 300   # 5 min visibility timeout
  visibility_timeout_seconds = 3600   # 6 times the Lambda function timeout (600 seconds) to allow for retries (source: https://docs.aws.amazon.com/lambda/latest/dg/with-sqs.html)
}

# SQS queue policy to allow lambda to write to queue
resource "aws_sqs_queue_policy" "lambda_sqs_policy" {
  queue_url = aws_sqs_queue.mros_sqs_queue.id
  policy    = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = "*",
        Action = "sqs:SendMessage",
        Resource = aws_sqs_queue.mros_sqs_queue.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_lambda_function.airtable_lambda_function.arn
          }
        }
      }
    ]
  })
}

# #############################################################
# # SQS Queue for S3 event notifications from the PROD bucket #
# #############################################################

# sqs_process_staged_queue
# sqs_s3_event_queue_stage

# SQS queue for S3 event notifications
resource "aws_sqs_queue" "sqs_prod_to_output_queue" {
  name                       = var.sqs_prod_to_output_queue_name
  delay_seconds              = 30
  max_message_size           = 2048
  message_retention_seconds  = 518400 # 6 day retention period
  receive_wait_time_seconds  = 20
  visibility_timeout_seconds = 1020   # Atleast 6 times the Lambda function timeout (150 seconds) to allow 
                                        # for retries + maximum_batching_window_in_seconds (20 seconds)
  # policy = data.aws_iam_policy_document.sqs_queue_policy_doc.json

}

# SQS queue policy to allow lambda to write to queue
resource "aws_sqs_queue_policy" "sqs_prod_to_output_queue_policy" {
  queue_url = aws_sqs_queue.sqs_prod_to_output_queue.id
  policy    = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = "*",
        Action = "sqs:SendMessage",
        Resource = aws_sqs_queue.sqs_prod_to_output_queue.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.prod_s3_bucket.arn
          }
        }
      }
    ]
  })
}
