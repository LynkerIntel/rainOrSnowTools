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
}


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

