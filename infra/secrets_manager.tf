# ####################
# # SECRETS MANAGERS #
# ####################

resource "aws_secretsmanager_secret" "airtable_secret" {
  name_prefix = var.airtable_secret_prefix
  recovery_window_in_days = 0
  description = "Secrets for MROS Airtable"
}

# AWS Secrets Manager Secret Version for Airtable Secrets
resource "aws_secretsmanager_secret_version" "airtable_secret_version" {
  secret_id     = aws_secretsmanager_secret.airtable_secret.id
  secret_string = jsonencode({
    "AIRTABLE_BASE_ID"     = var.airtable_base_id
    "AIRTABLE_TABLE_ID"    = var.airtable_table_id
    "AIRTABLE_API_TOKEN"   = var.airtable_api_token
  })
}
