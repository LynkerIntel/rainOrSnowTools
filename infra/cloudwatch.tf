######################################
# Lambda Log Group (mros_airtable_to_sqs) #
######################################

# Cloudwatch log group for 'mros_airtable_to_sqs' Python lambda function
resource "aws_cloudwatch_log_group" "airtable_lambda_log_group" {
  name              = "/aws/lambda/${var.mros_airtable_to_sqs_lambda_function_name}"
#   name_prefix              = "/aws/lambda/${var.mros_airtable_to_sqs_lambda_function_name}"
  retention_in_days = 14
  skip_destroy = false
#   skip_destroy = true
}

##########################################
# Lambda Log Group (mros_stage_to_prod) #
##########################################

# Cloudwatch log group for 'mros_stage_to_prod' Python lambda function
resource "aws_cloudwatch_log_group" "staging_lambda_log_group" {
  name              = "/aws/lambda/${var.mros_stage_to_prod_lambda_function_name}"
#   name_prefix              = "/aws/lambda/${var.mros_stage_to_prod_lambda_function_name}"
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
#   skip_destroy = true
}

##############################################################
# Lambda Log Group (Prod to Output - mros_append_daily_data) #
##############################################################

# Cloudwatch log group for 'mros_append_daily_data' python lambda function
resource "aws_cloudwatch_log_group" "prod_to_output_lambda_log_group" {
  name              = "/aws/lambda/${var.mros_append_daily_data_lambda_function_name}"
#   name_prefix = "/aws/lambda/${var.mros_append_daily_data_lambda_function_name}"
  retention_in_days = 14
  skip_destroy = false
#   skip_destroy = true
}

###########################################
# Lambda Log Group (Insert into DynamoDB) #
###########################################

# Cloudwatch log group for 'insert_into_dynamodb' python lambda function
resource "aws_cloudwatch_log_group" "insert_into_dynamodb_lambda_log_group" {
  name              = "/aws/lambda/${var.insert_into_dynamodb_lambda_function_name}"
#   name_prefix = "/aws/lambda/${var.insert_into_dynamodb_lambda_function_name}"
  retention_in_days = 14
  skip_destroy = false
#   skip_destroy = true
}