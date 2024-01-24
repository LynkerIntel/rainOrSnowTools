#####################################
# EventBridge Rule for Lambda Event #
#####################################

# EventBridge rule to trigger lambda function
resource "aws_cloudwatch_event_rule" "airtable_event_rule" {
  name                = var.eventbridge_cron_rule_name
  description         = "Event rule to trigger lambda function"
  schedule_expression = "rate(2 minutes)"
#   tags = {
#     name              = local.name_tag
#     resource_category = "eventbridge"
#   }
}

# EventBridge target for lambda function
resource "aws_cloudwatch_event_target" "airtable_event_target" {
  rule      = aws_cloudwatch_event_rule.airtable_event_rule.name
  target_id = "airtable_event_target"
  arn       = aws_lambda_function.airtable_lambda_function.arn
#   tags = {
#     name              = local.name_tag
#     resource_category = "eventbridge"
#   }
} 