######################################
# Lambda Log Group (airtable_to_sqs) #
######################################

# Cloudwatch log group for 'airtable_to_sqs' Python lambda function
resource "aws_cloudwatch_log_group" "airtable_lambda_log_group" {
  name              = "/aws/lambda/${var.airtable_to_sqs_lambda_function_name}"
#   name_prefix              = "/aws/lambda/${var.airtable_to_sqs_lambda_function_name}"
  retention_in_days = 14
  skip_destroy = false
#   skip_destroy = true
}

##########################################
# Lambda Log Group (stage_s3_to_prod_s3) #
##########################################

# Cloudwatch log group for 'stage_s3_to_prod_s3' Python lambda function
resource "aws_cloudwatch_log_group" "staging_lambda_log_group" {
  name              = "/aws/lambda/${var.stage_s3_to_prod_s3_lambda_function_name}"
#   name_prefix              = "/aws/lambda/${var.stage_s3_to_prod_s3_lambda_function_name}"
  retention_in_days = 14
  skip_destroy = false
#   skip_destroy = true
}

###################################
# Lambda Log Group (SQS Consumer) #
###################################

# Cloudwatch log group for 'sqs_consumer' R lambda function
resource "aws_cloudwatch_log_group" "sqs_consumer_lambda_log_group" {
  name              = "/aws/lambda/${var.sqs_consumer_lambda_function_name}"
#   name_prefix = "/aws/lambda/${var.sqs_consumer_lambda_function_name}"
  retention_in_days = 14
  skip_destroy = false
  # skip_destroy = true
}

###################################
# Lambda Log Group (Prod to Output) #
###################################

# Cloudwatch log group for 'sqs_consumer' R lambda function
resource "aws_cloudwatch_log_group" "prod_to_output_lambda_log_group" {
  name              = "/aws/lambda/${var.mros_append_daily_data_lambda_function_name}"
#   name_prefix = "/aws/lambda/${var.sqs_consumer_lambda_function_name}"
  retention_in_days = 14
  skip_destroy = false
  # skip_destroy = true
}