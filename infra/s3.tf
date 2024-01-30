
###################################################
# S3 bucket for storing the Terraform state files #
###################################################

# s3 bucket for Terraform state files
data "aws_s3_bucket" "terraform_state_s3_bucket" {
  bucket = var.tfstate_s3_bucket_name
}


# ###############################
# # S3 bucket for airtable data #
# ###############################

# # s3 bucket for lambda code
# resource "aws_s3_bucket" "airtable_s3_bucket" {
#   bucket = var.airtable_s3_bucket_name
# }

###############################
# S3 Staging JSON data #
###############################

# s3 bucket for lambda code
resource "aws_s3_bucket" "staging_s3_bucket" {
  bucket = var.staging_s3_bucket_name
}

###############################
# S3 bucket for airtable data #
###############################

# s3 bucket for lambda code
resource "aws_s3_bucket" "prod_s3_bucket" {
  bucket = var.prod_s3_bucket_name
}

####################
# OUTPUT S3 bucket #
####################

# s3 bucket for lambda code
data "aws_s3_bucket" "output_s3_bucket" {
  bucket = var.output_s3_bucket_name
}

#######################################
# S3 bucket for Lambda Functions code #
#######################################

# s3 bucket for lambda code
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = var.lambda_bucket_name
}


#####################################
# S3 Objects (Lambda function code) #
#####################################


# s3 object for lambda code for mros_airtable_to_sqs function
resource "aws_s3_object" "airtable_lambda_code_object" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = var.mros_airtable_to_sqs_lambda_zip_file_name
  source = local.mros_airtable_to_sqs_zip
  etag   = filemd5(local.mros_airtable_to_sqs_zip)
  # source = var.mros_airtable_to_sqs_zip
  # etag   = filemd5(var.mros_airtable_to_sqs_zip)
}

# s3 object for lambda code process_staging function
resource "aws_s3_object" "staging_lambda_code_object" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = var.mros_stage_to_prod_lambda_zip_file_name
  source = local.mros_stage_to_prod_zip
  etag   = filemd5(local.mros_stage_to_prod_zip)
}

# s3 object for lambda code mros_append_daily_data lambda function
resource "aws_s3_object" "prod_to_output_lambda_code_object" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = var.mros_append_daily_data_lambda_zip_file_name
  source = local.mros_append_daily_data_zip
  etag   = filemd5(local.mros_append_daily_data_zip)
}

# s3 object for lambda code mros_append_daily_data lambda function
resource "aws_s3_object" "insert_into_dynamodb_lambda_code_object" {
  bucket = aws_s3_bucket.lambda_bucket.bucket
  key    = var.insert_into_dynamodb_lambda_zip_file_name
  source = local.mros_insert_into_dynamodb_zip
  etag   = filemd5(local.mros_insert_into_dynamodb_zip)
}

# #######################################
# # S3 bucket permissions airtable data #
# #######################################

# # s3 bucket ownership controls
# resource "aws_s3_bucket_ownership_controls" "airtable_s3_bucket_ownership_controls" {
#   bucket = aws_s3_bucket.airtable_s3_bucket.id
#   rule {
#     object_ownership = "BucketOwnerPreferred"
#   }
# }

# # s3 bucket public access block
# resource "aws_s3_bucket_public_access_block" "airtable_s3_public_access_block" {
#   bucket = aws_s3_bucket.airtable_s3_bucket.id
#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true

# }

# resource "aws_s3_bucket_acl" "airtable_s3_bucket_acl" {
#   depends_on = [
#     aws_s3_bucket_ownership_controls.airtable_s3_bucket_ownership_controls,
#     aws_s3_bucket_public_access_block.airtable_s3_public_access_block,
#   ]

#   bucket = aws_s3_bucket.airtable_s3_bucket.id
#   acl    = "private"
# }

# # s3 bucket policy to allow public access
# resource "aws_s3_bucket_policy" "airtable_bucket_policy" {
#   bucket = aws_s3_bucket.airtable_s3_bucket.id
#   policy = data.aws_iam_policy_document.s3_bucket_policy_document.json
#   depends_on = [
#     aws_s3_bucket_acl.airtable_s3_bucket_acl,
#     aws_s3_bucket_ownership_controls.airtable_s3_bucket_ownership_controls,
#     aws_s3_bucket_public_access_block.airtable_s3_public_access_block,
#   ]
# }

#################################
# Staging S3 bucket permissions #
#################################

# s3 bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "staging_s3_bucket_ownership_controls" {
  bucket = aws_s3_bucket.staging_s3_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# s3 bucket public access block
resource "aws_s3_bucket_public_access_block" "staging_s3_public_access_block" {
  bucket = aws_s3_bucket.staging_s3_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

}

resource "aws_s3_bucket_acl" "staging_s3_bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.staging_s3_bucket_ownership_controls,
    aws_s3_bucket_public_access_block.staging_s3_public_access_block,
  ]

  bucket = aws_s3_bucket.staging_s3_bucket.id
  acl    = "private"
}

# s3 bucket policy to allow public access
resource "aws_s3_bucket_policy" "staging_bucket_policy" {
  bucket = aws_s3_bucket.staging_s3_bucket.id
  policy = data.aws_iam_policy_document.staging_s3_bucket_policy_document.json
  depends_on = [
    aws_s3_bucket_acl.staging_s3_bucket_acl,
    aws_s3_bucket_ownership_controls.staging_s3_bucket_ownership_controls,
    aws_s3_bucket_public_access_block.staging_s3_public_access_block,
  ]
}


#################################
# Staging S3 bucket permissions #
#################################

# s3 bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "prod_s3_bucket_ownership_controls" {
  bucket = aws_s3_bucket.prod_s3_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# s3 bucket public access block
resource "aws_s3_bucket_public_access_block" "prod_s3_public_access_block" {
  bucket = aws_s3_bucket.prod_s3_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

}

resource "aws_s3_bucket_acl" "prod_s3_bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.prod_s3_bucket_ownership_controls,
    aws_s3_bucket_public_access_block.prod_s3_public_access_block,
  ]

  bucket = aws_s3_bucket.prod_s3_bucket.id
  acl    = "private"
}

# s3 bucket policy to allow public access
resource "aws_s3_bucket_policy" "prod_bucket_policy" {
  bucket = aws_s3_bucket.prod_s3_bucket.id
  policy = data.aws_iam_policy_document.prod_s3_bucket_policy_document.json
  depends_on = [
    aws_s3_bucket_acl.prod_s3_bucket_acl,
    aws_s3_bucket_ownership_controls.prod_s3_bucket_ownership_controls,
    aws_s3_bucket_public_access_block.prod_s3_public_access_block,
  ]
}

######################################
# OUTPUT S3 bucket Enable versioning #
######################################

# Enable object versioning on OUTPUT S3 bucket
resource "aws_s3_bucket_versioning" "output_s3_bucket_versioning" {
  bucket = data.aws_s3_bucket.output_s3_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# OUTPUT S3 Bucket stationary CSV file for appending

data "aws_s3_object" "output_s3_bucket_stationary_csv" {
  bucket = data.aws_s3_bucket.output_s3_bucket.id
  key    = "mros_output.csv"
#   source = local.stationary_csv
#   etag   = filemd5(local.stationary_csv)
}

################################
# OUTPUT S3 bucket permissions #
################################

# s3 bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "output_s3_bucket_ownership_controls" {
  bucket = data.aws_s3_bucket.output_s3_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# s3 bucket public access block
resource "aws_s3_bucket_public_access_block" "output_s3_public_access_block" {
  bucket = data.aws_s3_bucket.output_s3_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

}

resource "aws_s3_bucket_acl" "output_s3_bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.output_s3_bucket_ownership_controls,
    aws_s3_bucket_public_access_block.output_s3_public_access_block,
  ]

  bucket =  data.aws_s3_bucket.output_s3_bucket.id
  acl    = "private"
}

# s3 bucket policy to allow public access
resource "aws_s3_bucket_policy" "output_bucket_policy" {
  bucket = data.aws_s3_bucket.output_s3_bucket.id
  policy = data.aws_iam_policy_document.output_s3_bucket_policy_document.json
  depends_on = [
    aws_s3_bucket_acl.output_s3_bucket_acl,
    aws_s3_bucket_ownership_controls.output_s3_bucket_ownership_controls,
    aws_s3_bucket_public_access_block.output_s3_public_access_block,
  ]
}

