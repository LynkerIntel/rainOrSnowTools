# ---------------------------------
# ---- SNS topic IAM policy ----
# ---------------------------------

# SNS topic policy that allows S3 to publish to the SNS topic
data "aws_iam_policy_document" "sns_topic_policy_doc" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.sns_output_data_topic.arn]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.prod_s3_bucket.arn]
    }
    
    # # Build ARN for S3 bucket manually to avoid circular dependency
    # condition {
    #   test     = "ArnLike"
    #   variable = "aws:SourceArn"
    #   values   = ["arn:aws:s3:::${var.prod_s3_bucket_name}"]
    # }
    
    
  }
}

# SNS topic policy that allows SQS to subscribe to the SNS topic
resource "aws_sns_topic_policy" "sns_topic_policy" {
  arn = aws_sns_topic.sns_output_data_topic.arn
  policy = data.aws_iam_policy_document.sns_topic_policy_doc.json
}

# ---------------------------------
# ---- SNS Topic ----
# ---------------------------------

# SNS topic that receives S3 event notifications from the prod bucket when new data is uploaded
resource "aws_sns_topic" "sns_output_data_topic" {
  name = var.sns_output_data_topic
#   policy = data.aws_iam_policy_document.sns_topic_policy_doc.json
#   depends_on = [data.aws_iam_policy_document.sns_topic_policy_doc]
}

# ---------------------------------
# ---- SNS Topic Subscriptions ----
# ---------------------------------

# Subscribe SQS prod to output queue to SNS topic to get S3 event notifications
resource "aws_sns_topic_subscription" "sqs_prod_to_output_sns_subscription" {
  topic_arn = aws_sns_topic.sns_output_data_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.sqs_prod_to_output_queue.arn
}

# Subscribe Lambda function (Insert into DynamoDB) to SNS topic, so that 
# SNS triggers Lambda function each time S3 event notification comes in and 
# the CSV that was created in the S3 bucket gets processed and inserted into DynamoDB
resource "aws_sns_topic_subscription" "lambda_insert_into_dynamodb_sns_subscription" {
  topic_arn = aws_sns_topic.sns_output_data_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.insert_into_dynamodb_lambda_function.arn
}

