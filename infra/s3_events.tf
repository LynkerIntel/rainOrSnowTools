# Create S3 event notification to send messages to SQS queue 
# when a JSON file is uploaded to the STAGE S3 bucket (scraped data)
resource "aws_s3_bucket_notification" "stage_s3_bucket_notification" {
  bucket = aws_s3_bucket.staging_s3_bucket.id

  queue {
    queue_arn     = aws_sqs_queue.sqs_stage_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".json"
  }
}

# Create S3 event notification to publish messages to SNS topic 
# when a CSV file is uploaded to the PROD S3 bucket 
# SNS topic then fans out to SQS queue and Lambda function that inserts data into DynamoDB
resource "aws_s3_bucket_notification" "prod_s3_bucket_notification" {
  bucket = aws_s3_bucket.prod_s3_bucket.id

  topic {
    topic_arn     = aws_sns_topic.sns_output_data_topic.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".csv"
  }
  depends_on = [
    aws_s3_bucket.prod_s3_bucket,
    aws_sns_topic.sns_output_data_topic
    ]
  # depends_on = [aws_s3_bucket.prod_s3_bucket]
}

# # Create S3 event notification to trigger lambda function to convert CSV to parquet 
# # when a new object is put into Output S3 Bucket
# # IMPORTANT: SUFFIX MUST REMAIN as specific file name as 
# # the lambda function writes to the same S3 bucket and we DON'T WANT AN INFINITE LOOP
# resource "aws_s3_bucket_notification" "output_s3_bucket_notification" {
#   bucket = data.aws_s3_bucket.output_s3_bucket.id

#   lambda_function {
#     lambda_function_arn = aws_lambda_function.func2.arn
#     events              = ["s3:ObjectCreated:*"]
#     filter_prefix = "mros_output"
#     filter_suffix = ".csv"
#   }

#   topic {
#     topic_arn     = aws_sns_topic.sns_output_data_topic.arn
#     events        = ["s3:ObjectCreated:Put"]
#     filter_suffix = "mros_output.csv"
#   }
#   depends_on = [
#     aws_s3_bucket.prod_s3_bucket,
#     aws_sns_topic.sns_output_data_topic
#     ]
#   # depends_on = [aws_s3_bucket.prod_s3_bucket]
# }

# # Create S3 event notification to send messages to SQS queue 
# # when a CSV file is uploaded to the PROD S3 bucket 
# resource "aws_s3_bucket_notification" "prod_s3_bucket_notification" {
#   bucket = aws_s3_bucket.prod_s3_bucket.id

#   queue {
#     queue_arn     = aws_sqs_queue.sqs_prod_to_output_queue.arn
#     events        = ["s3:ObjectCreated:*"]
#     # filter_suffix = ".json"
#     filter_suffix = ".csv"
#   }
# }

