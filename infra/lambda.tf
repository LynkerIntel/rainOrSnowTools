
####################################
# Lambda Function (Airtable to S3) #
####################################

# lambda function to process csv file
resource "aws_lambda_function" "airtable_lambda_function" {
  s3_bucket        = aws_s3_bucket.lambda_bucket.bucket
  s3_object_version = aws_s3_object.airtable_lambda_code_object.version_id
  s3_key           = var.airtable_to_sqs_lambda_zip_file_name
  source_code_hash = var.airtable_to_sqs_lambda_zip_file_name
  function_name    = var.airtable_to_sqs_lambda_function_name
  handler          = "airtable_to_sqs.airtable_to_sqs.airtable_to_sqs"
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
        # S3_BUCKET = "s3://${aws_s3_bucket.airtable_s3_bucket.bucket}",
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
  
  tags = {
    name              = local.name_tag
    resource_category = "lambda"
  }
}

# resource "aws_lambda_permission" "lambda_put_to_s3_permission" {
#   statement_id  = "AllowExecutionFromS3"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.airtable_lambda_function.function_name
#   principal     = "s3.amazonaws.com"
#   source_arn    = aws_s3_bucket.airtable_s3_bucket.arn
# }

#############################################################
# Lambda Permissions for CloudWatch Events to invoke Lambda #
#############################################################

resource "aws_lambda_permission" "cloudwatch_invoke_lambda_permission" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.airtable_lambda_function.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.airtable_event_rule.arn
}


####################################
# Lambda Function (Staging to S3) #
####################################

# lambda function to process csv file
resource "aws_lambda_function" "staging_lambda_function" {
  s3_bucket        = aws_s3_bucket.lambda_bucket.bucket
  s3_object_version = aws_s3_object.staging_lambda_code_object.version_id
  s3_key           = var.stage_s3_to_prod_s3_lambda_zip_file_name
  source_code_hash = var.stage_s3_to_prod_s3_lambda_zip_file_name
  function_name    = var.stage_s3_to_prod_s3_lambda_function_name
  handler          = "stage_s3_to_prod_s3.stage_s3_to_prod_s3.stage_s3_to_prod_s3"
  
  # Lambda role (with permissions for SQS)   
  role             = aws_iam_role.sqs_consumer_lambda_role.arn
  #   role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.11"
  architectures    = ["x86_64"]
  # architectures    = ["arm64"]

  # Attach the Lambda function to the CloudWatch Logs group
  environment {
    variables = {
        CW_LOG_GROUP = aws_cloudwatch_log_group.staging_lambda_log_group.name,
        # S3_BUCKET = "s3://${aws_s3_bucket.staging_s3_bucket.bucket}",
        # S3_STAGING_BUCKET = "s3://${aws_s3_bucket.staging_s3_bucket.bucket}",
        # S3_PROD_BUCKET = "s3://${aws_s3_bucket.prod_s3_bucket.bucket}",
        # S3_STAGING_BUCKET_NAME = aws_s3_bucket.staging_s3_bucket.bucket,
        # S3_PROD_BUCKET_NAME = aws_s3_bucket.prod_s3_bucket.bucket
        S3_STAGE_BUCKET = aws_s3_bucket.staging_s3_bucket.bucket,
        S3_PROD_BUCKET = aws_s3_bucket.prod_s3_bucket.bucket,
        S3_STAGE_BUCKET_URI = "s3://${aws_s3_bucket.staging_s3_bucket.bucket}",
        S3_PROD_BUCKET_URI = "s3://${aws_s3_bucket.prod_s3_bucket.bucket}"

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
  tags = {
    name              = local.name_tag
    resource_category = "lambda"
  }
}

# resource "aws_lambda_permission" "lambda_put_to_s3_permission" {
#   statement_id  = "AllowExecutionFromS3"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.airtable_lambda_function.function_name
#   principal     = "s3.amazonaws.com"
#   source_arn    = aws_s3_bucket.airtable_s3_bucket.arn
# }

################################################
# Lambda (sqs_consumer) SQS Event Source Mapping
################################################

# Lambda SQS Event Source Mapping
resource "aws_lambda_event_source_mapping" "sqs_stage_lambda_event_source_mapping" {
  event_source_arn = aws_sqs_queue.sqs_stage_queue.arn
  function_name    = aws_lambda_function.staging_lambda_function.function_name
  batch_size       = 40
  maximum_batching_window_in_seconds = 20      # (max time to wait for batch to fill up)
  function_response_types = ["ReportBatchItemFailures"]
  depends_on = [
    aws_lambda_function.staging_lambda_function,
    aws_sqs_queue.sqs_stage_queue,
  ]
}

# Allow the staging SQS queue to invoke the staging_lambda_function Lambda function
resource "aws_lambda_permission" "allow_sqs_invoke_stage_to_prod_lambda" {
  statement_id  = "AllowSQSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.staging_lambda_function.arn}"
  principal = "sqs.amazonaws.com"
  source_arn = "${aws_sqs_queue.sqs_stage_queue.arn}"
}

################################
# Lambda SQS consumer R function
################################

# Create Lambda function for R Docker image
resource "aws_lambda_function" "sqs_consumer_lambda_function" {
  function_name    = var.sqs_consumer_lambda_function_name
  # role             = aws_iam_role.lambda_role.arn
  # handler          = "sqs_consumer.sqs_consumer"
  # runtime          = "provided.al2"

    image_uri        = "${var.sqs_consumer_ecr_repo_url}:latest"
#   image_uri = data.aws_ecr_image.repo_image.image_uri
  
  # image_uri        = "${data.aws_ecr_repository.r_ecr_repository.repository_url}:latest"
  # image_uri        = data.aws_ecr_repository.r_ecr_repository.repository_url
  package_type     = "Image"
  memory_size      = 800
  # memory_size      = 3009
  timeout          = 600     # timeout in seconds
  role             = aws_iam_role.sqs_consumer_lambda_role.arn
  architectures    = ["x86_64"]
  # architectures    = ["arm64"]
  
  # force a new resource when the image is updated /changes
  source_code_hash = trimprefix(data.aws_ecr_image.repo_image.id, "sha256:")

    # Attach the Lambda function to the CloudWatch Logs group
  environment {
    variables = {
        CW_LOG_GROUP = aws_cloudwatch_log_group.sqs_consumer_lambda_log_group.name,
        NASA_DATA_USER = var.nasa_data_user_env_var,
        NASA_DATA_PASSWORD = var.nasa_data_password_env_var,
        SQS_QUEUE_NAME = aws_sqs_queue.mros_sqs_queue.name,
        SQS_QUEUE_URL  = aws_sqs_queue.mros_sqs_queue.url,
        S3_BUCKET_NAME = var.staging_s3_bucket_name,
    }
  }

  depends_on = [
    data.aws_ecr_repository.r_ecr_repository,
    aws_iam_role_policy_attachment.sqs_consumer_lambda_basic_exec_policy_attachment,
    aws_iam_role_policy_attachment.sqs_consumer_lambda_policy_attachment,
    aws_cloudwatch_log_group.sqs_consumer_lambda_log_group,
    aws_sqs_queue.mros_sqs_queue,
  ]
  tags = {
    name              = local.name_tag
    resource_category = "lambda"
  }
}

################################################
# Lambda (sqs_consumer) SQS Event Source Mapping
################################################

# Lambda SQS Event Source Mapping
resource "aws_lambda_event_source_mapping" "sqs_consumer_lambda_event_source_mapping" {
  event_source_arn = aws_sqs_queue.mros_sqs_queue.arn
  function_name    = aws_lambda_function.sqs_consumer_lambda_function.function_name
  batch_size       = 1
  depends_on = [
    aws_lambda_function.sqs_consumer_lambda_function,
    aws_sqs_queue.mros_sqs_queue,
  ]
}

####################################################################################
# Lambda function (mros_append_daily_data - Triggered by new CSV datasets being put
#  into PROD S3 BUCKET which get sent into SQS queue) #
####################################################################################

# lambda function triggered when a CSV file is uploaded to the Prod S3 bucket (ObjectCreated)
# Function downloads the new CSV file and the stationary CSV file from the OUTPUT bucket and then concatenates them
resource "aws_lambda_function" "mros_append_daily_data_lambda_function" {
  s3_bucket        = aws_s3_bucket.lambda_bucket.bucket
  s3_key           = var.mros_append_daily_data_lambda_zip_file_name
  s3_object_version = aws_s3_object.prod_to_output_lambda_code_object.version_id
  source_code_hash = var.mros_append_daily_data_lambda_zip_file_name
  # source_code_hash = filebase64sha256(local.recipe_scraper_lambda_zip)
  # source_code_hash = aws_s3_object.recipe_scraper_lambda_code_object.etag

  function_name    = var.mros_append_daily_data_lambda_function_name
  handler          = "mros_append_daily_data.mros_append_daily_data.mros_append_daily_data"
  role             = aws_iam_role.sqs_consumer_lambda_role.arn
  runtime          = "python3.11"
  architectures    = ["x86_64"]
  # architectures    = ["arm64"]

  # # Pandas lambda layer
  # layers = ["arn:aws:lambda:us-west-1:336392948345:layer:AWSSDKPandas-Python311:4"]
  # # layers = ["arn:aws:lambda:us-west-1:336392948345:layer:AWSSDKPandas-Python39:14"]

  # timeout in seconds
  timeout         = 750

  # memory in MB
  memory_size     = 1024

  # Only allow for a maximum of 8 Lambdas to be run concurrently
  reserved_concurrent_executions = 1
  
  # Attach the Lambda function to the CloudWatch Logs group
  environment {
    variables = {
        CW_LOG_GROUP         = aws_cloudwatch_log_group.prod_to_output_lambda_log_group.name,
        OUTPUT_S3_BUCKET     = data.aws_s3_bucket.output_s3_bucket.bucket,
        OUTPUT_OBJECT_KEY    = "mros_output.csv"
  }
  }

  depends_on = [
    aws_s3_bucket.lambda_bucket,
    aws_s3_object.prod_to_output_lambda_code_object,
    # aws_s3_bucket_notification.raw_s3_bucket_notification,
    aws_iam_role_policy_attachment.lambda_logs_policy_attachment,
    aws_cloudwatch_log_group.prod_to_output_lambda_log_group,
    aws_s3_bucket.prod_s3_bucket,
  ]
  
  tags = {
    name              = local.name_tag
    resource_category = "lambda"
  }
}

# # Allow S3 to invoke the Lambda function
# resource "aws_lambda_permission" "allow_s3_invoke" {
#   statement_id  = "AllowS3Invoke"
#   action        = "lambda:InvokeFunction"
#   function_name = "${aws_lambda_function.recipe_scraper_lambda_function.arn}"
#   principal = "s3.amazonaws.com"
#   source_arn = "${aws_s3_bucket.raw_s3_bucket.arn}"
# }

####### ADD BACK THE BELOW CODE ##############
####### ADD BACK THE BELOW CODE ##############
####### ADD BACK THE BELOW CODE ##############

# ######################################################################################
# # Lambda SQS Event Source Mapping (map prod_to_output lambda to prod_to_output SQS queue) #
# ######################################################################################

# Lambda SQS Event Source Mapping
resource "aws_lambda_event_source_mapping" "prod_to_output_lambda_sqs_event_source_mapping" {
  event_source_arn = aws_sqs_queue.sqs_prod_to_output_queue.arn
  function_name    = aws_lambda_function.mros_append_daily_data_lambda_function.function_name
  batch_size       = 1
  maximum_batching_window_in_seconds = 20      # (max time to wait for batch to fill up)
#   function_response_types = ["ReportBatchItemFailures"]
  depends_on = [
    aws_lambda_function.mros_append_daily_data_lambda_function,
    aws_sqs_queue.sqs_prod_to_output_queue,
  ]
}

# Allow the "to prod_to_output" SQS queue to invoke the mros_append_daily_data Lambda function
resource "aws_lambda_permission" "allow_sqs_invoke_prod_to_output_lambda" {
  statement_id  = "AllowSQSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.mros_append_daily_data_lambda_function.arn}"
  principal = "sqs.amazonaws.com"
  source_arn = "${aws_sqs_queue.sqs_prod_to_output_queue.arn}"
}

####### ADD BACK THE ABOVE CODE ##############
####### ADD BACK THE ABOVE CODE ##############
####### ADD BACK THE ABOVE CODE ##############

####################################################################################
# Lambda function (mros_append_daily_data - Triggered by new CSV datasets being put
#  into PROD S3 BUCKET which get sent into SQS queue) #
####################################################################################

# lambda function triggered when a CSV file is uploaded to the Prod S3 bucket (ObjectCreated)
# Function downloads the new CSV file and the stationary CSV file from the OUTPUT bucket and then concatenates them
resource "aws_lambda_function" "insert_into_dynamodb_lambda_function" {
  s3_bucket        = aws_s3_bucket.lambda_bucket.bucket
  s3_key           = var.insert_into_dynamodb_lambda_zip_file_name
  s3_object_version = aws_s3_object.prod_to_output_lambda_code_object.version_id
  source_code_hash = var.insert_into_dynamodb_lambda_zip_file_name
  # source_code_hash = filebase64sha256(local.recipe_scraper_lambda_zip)
  # source_code_hash = aws_s3_object.recipe_scraper_lambda_code_object.etag

  function_name    = var.insert_into_dynamodb_lambda_function_name
  handler          = "mros_insert_into_dynamodb.mros_insert_into_dynamodb.mros_insert_into_dynamodb"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.11"
  architectures    = ["x86_64"]
  # architectures    = ["arm64"]

  # # Pandas lambda layer
  layers = ["arn:aws:lambda:us-west-1:336392948345:layer:AWSSDKPandas-Python311:6"]
  # # layers = ["arn:aws:lambda:us-west-1:336392948345:layer:AWSSDKPandas-Python39:14"]

  # timeout in seconds
  timeout         = 750

  # memory in MB
  memory_size     = 1024

  # Only allow for a maximum of 5 Lambdas to be run concurrently
  reserved_concurrent_executions = 5
  
  # Attach the Lambda function to the CloudWatch Logs group
  environment {
    variables = {
        CW_LOG_GROUP         = aws_cloudwatch_log_group.insert_into_dynamodb_lambda_log_group.name,
        DYNAMODB_TABLE       = aws_dynamodb_table.mros_dynamodb_table.name,
  }
  }

  depends_on = [
    aws_s3_bucket.lambda_bucket,
    aws_s3_object.insert_into_dynamodb_lambda_code_object,
    # aws_s3_bucket_notification.raw_s3_bucket_notification,
    aws_iam_role_policy_attachment.lambda_logs_policy_attachment,
    aws_cloudwatch_log_group.insert_into_dynamodb_lambda_log_group,
    aws_dynamodb_table.mros_dynamodb_table,
  ]
  
  tags = {
    name              = local.name_tag
    resource_category = "lambda"
  }
}

# # Allow S3 to invoke the Lambda function
# resource "aws_lambda_permission" "allow_s3_invoke" {
#   statement_id  = "AllowS3Invoke"
#   action        = "lambda:InvokeFunction"
#   function_name = "${aws_lambda_function.recipe_scraper_lambda_function.arn}"
#   principal = "s3.amazonaws.com"
#   source_arn = "${aws_s3_bucket.raw_s3_bucket.arn}"
# }

####### ADD BACK THE BELOW CODE ##############
####### ADD BACK THE BELOW CODE ##############
####### ADD BACK THE BELOW CODE ##############

# #################################################################################################
# # Lambda SNS permission (allow SNS topic to invoke insert_into_dynamodb_lambda lambda function) #
# #################################################################################################

# Allow the "sns_output_data_topic" SNS topic to invoke the insert_into_dynamodb_lambda Lambda function
resource "aws_lambda_permission" "allow_sns_invoke_insert_into_dynamodb_lambda" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.insert_into_dynamodb_lambda_function.arn}"
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.sns_output_data_topic.arn
}