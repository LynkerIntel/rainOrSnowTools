# Create S3 event notification to send messages to SQS queue 
# when a JSON file is uploaded to the STAGE S3 bucket (scraped data)
resource "aws_s3_bucket_notification" "prod_s3_bucket_notification" {
  bucket = aws_s3_bucket.prod_s3_bucket.id

  queue {
    queue_arn     = aws_sqs_queue.sqs_prod_to_output_queue.arn
    events        = ["s3:ObjectCreated:*"]
    # filter_suffix = ".json"
    filter_suffix = ".csv"
  }
}