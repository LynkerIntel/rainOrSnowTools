#!/bin/bash

# Create a ECR repository for use by the infrastructure created by Terraform (e.g. Docker images). 
# This script is run before terraform plan/apply to ensure that certain stack resources (ECR repository, S3 buckets, etc)
#  exist before terraform tries to use the Docker Image while creating infrastructure (e.g. Lambda functions in this case)


# Provide following as arguments to script: 
# AWS Account Number
# S3 bucket name
# Terraform state S3 bucket name
# AWS region
# AWS profile
# RUNNING_ON_GITHUB_ACTION
# Example: source sh/setup_static_buckets.sh 123456789 outputs-bucket-name tfstate-s3-bucket-name aws-region aws-profile false

# AWS Account Number
AWS_ACCOUNT_NUMBER=$1

# S3 bucket
BUCKET_NAME=$2
# BUCKET_NAME="mros-output-bucket"

# Terraform state S3 bucket name
TF_STATE_S3_BUCKET_NAME=$3

# AWS Region to create/check resources, if not given, use "us-west-1"
AWS_REGION=${4:-"us-west-1"}
LOCATION_CONSTRAINT=${AWS_REGION}

# AWS Profile, if not given, use "default"
AWS_PROFILE=${5:-"default"}

# Flag to determine whether to export variables to $GITHUB_ENV
RUNNING_ON_GITHUB_ACTION=${6:-"false"}

echo "- BUCKET_NAME: $BUCKET_NAME"
echo "- TF_STATE_S3_BUCKET_NAME: $TF_STATE_S3_BUCKET_NAME"
echo "- AWS_REGION: $AWS_REGION"
echo "- LOCATION_CONSTRAINT: $LOCATION_CONSTRAINT"
echo "- AWS_PROFILE: $AWS_PROFILE"

# -----------------------------------------------------------------------------------------------
# ----- Generate an empty CSV file to upload to S3 -----
# ----- (This is the CSV that gets updated updated by new processed data from the Airtable) -----
# -----------------------------------------------------------------------------------------------

# # Create a temporary CSV file in the system's temporary directory
# TEMP_DIR=$(mktemp -t temp.csv)
# echo "Temporary directory created: $TEMP_DIR"

# # Full path to the random CSV file
# LOCAL_CSV_PATH="$TEMP_DIR"

# Path to save local CSV file path of skeleton CSV file to upload to S3
LOCAL_CSV_PATH="./tmp_empty_output.csv"

echo "Local CSV path: $LOCAL_CSV_PATH"

# S3 object key and CSV file content
S3_OBJECT_KEY="mros_output.csv"

# CSV headers for mros_output.csv
CSV_CONTENT="id,timestamp,createdtime,name,latitude,user,longitude,submitted_time,local_time,submitted_date,local_date,comment,time,duplicate_id,duplicate_count,\
temp_air_idw_lapse_const,temp_air_idw_lapse_var,temp_air_nearest_site_const,temp_air_nearest_site_var,temp_air_avg_obs,temp_air_min_obs,temp_air_max_obs,\
temp_air_lapse_var,temp_air_lapse_var_r2,temp_air_lapse_var_pval,temp_air_n_stations,temp_air_avg_time_gap,temp_air_avg_dist,temp_air_nearest_id,\
temp_air_nearest_elev,temp_air_nearest_dist,temp_air_nearest,temp_dew_idw_lapse_const,temp_dew_idw_lapse_var,temp_dew_nearest_site_const,\
temp_dew_nearest_site_var,temp_dew_avg_obs,temp_dew_min_obs,temp_dew_max_obs,temp_dew_lapse_var,temp_dew_lapse_var_r2,temp_dew_lapse_var_pval,\
temp_dew_n_stations,temp_dew_avg_time_gap,temp_dew_avg_dist,temp_dew_nearest_id,temp_dew_nearest_elev,temp_dew_nearest_dist,temp_dew_nearest,rh,\
temp_wet,hads_counts,lcd_counts,wcc_counts,plp_data,state,geohash5,geohash12,date_key,record_hash"
# CSV_CONTENT="id,timestamp,createdtime,name,latitude,user,longitude,submitted_time,local_time,submitted_date,local_date,comment,time,temp_air_idw_lapse_const,temp_air_idw_lapse_var,temp_air_nearest_site_const,temp_air_nearest_site_var,temp_air_avg_obs,temp_air_min_obs,temp_air_max_obs,temp_air_lapse_var,temp_air_lapse_var_r2,temp_air_lapse_var_pval,temp_air_n_stations,temp_air_avg_time_gap,temp_air_avg_dist,temp_air_nearest_id,temp_air_nearest_elev,temp_air_nearest_dist,temp_air_nearest,temp_dew_idw_lapse_const,temp_dew_idw_lapse_var,temp_dew_nearest_site_const,temp_dew_nearest_site_var,temp_dew_avg_obs,temp_dew_min_obs,temp_dew_max_obs,temp_dew_lapse_var,temp_dew_lapse_var_r2,temp_dew_lapse_var_pval,temp_dew_n_stations,temp_dew_avg_time_gap,temp_dew_avg_dist,temp_dew_nearest_id,temp_dew_nearest_elev,temp_dew_nearest_dist,temp_dew_nearest,rh,temp_wet,hads_counts,lcd_counts,wcc_counts,plp_data,date_key"

# Check if the local CSV file already exists
if [ ! -f "$LOCAL_CSV_PATH" ]; then
    # Create an empty CSV file with headers
    echo "$CSV_CONTENT" > "$LOCAL_CSV_PATH"
    echo "Empty CSV file created: $LOCAL_CSV_PATH"
else
    echo "CSV file $LOCAL_CSV_PATH already exists."
fi

# -----------------------------------------------------------------------------------------------
# ----- Create S3 bucket to keep Terraform state files (if does NOT exist) -----
# -----------------------------------------------------------------------------------------------

# check if Terraform state S3 bucket ALREADY EXISTS
if ! aws s3api head-bucket --bucket "$TF_STATE_S3_BUCKET_NAME" --profile "$AWS_PROFILE" 2>/dev/null; then
    # Create the Terraform state S3 bucket if it DOESN'T exist
    aws s3api create-bucket --bucket "$TF_STATE_S3_BUCKET_NAME" --region "$AWS_REGION"  --profile "$AWS_PROFILE" --create-bucket-configuration LocationConstraint="$LOCATION_CONSTRAINT"
    
    echo "S3 bucket $TF_STATE_S3_BUCKET_NAME created."

    # Enable versioning on the bucket
    aws s3api put-bucket-versioning --bucket "$TF_STATE_S3_BUCKET_NAME" --region "$AWS_REGION"  --profile "$AWS_PROFILE" --versioning-configuration Status=Enabled

else
    echo "Bucket $TF_STATE_S3_BUCKET_NAME already exists."
fi

# -----------------------------------------------------------------------------------------------
# ----- Create S3 bucket for mros_output.csv (DO NOT DELETE) -----
# -----------------------------------------------------------------------------------------------

# check if the output bucket ALREADY EXISTS
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" --profile "$AWS_PROFILE" 2>/dev/null; then
    echo "S3 bucket $BUCKET_NAME DOES NOT EXIST."
    
    # Create the output bucket if it DOESN'T exist
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION"  --profile "$AWS_PROFILE" --create-bucket-configuration LocationConstraint="$LOCATION_CONSTRAINT"
    
    echo "- S3 bucket $BUCKET_NAME created."

    # Enable versioning on the bucket
    aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --region "$AWS_REGION"  --profile "$AWS_PROFILE" --versioning-configuration Status=Enabled

    echo "- Versioning enabled on S3 bucket $BUCKET_NAME."
else
    echo "S3 bucket $BUCKET_NAME ALREADY EXIST with versioning enabled."
fi

# -----------------------------------------------------------------------------------------------
# ----- Check if "mros_output.csv" is in the S3 Bucket and upload if does NOT exist -----
# -----------------------------------------------------------------------------------------------

# Upload empty CSV file if it does NOT already exist
if ! aws s3api head-object --bucket "$BUCKET_NAME" --key "$S3_OBJECT_KEY" --region "$AWS_REGION" --profile "$AWS_PROFILE" 2>/dev/null; then

    echo "$S3_OBJECT_KEY DOES NOT EXIST in S3 bucket $BUCKET_NAME."
    echo "- Uploading empty CSV file to S3 bucket $BUCKET_NAME/$S3_OBJECT_KEY"

    # Upload an empty CSV file
    aws s3 cp "$LOCAL_CSV_PATH" s3://"$BUCKET_NAME"/"$S3_OBJECT_KEY" --region "$AWS_REGION" --profile "$AWS_PROFILE"
    # echo "$CSV_CONTENT" | aws s3 cp - s3://"$BUCKET_NAME"/"$S3_OBJECT_KEY" --region "$AWS_REGION" --profile "$AWS_PROFILE"
    
    echo "- Empty CSV file uploaded to S3: $BUCKET_NAME/$S3_OBJECT_KEY"
else
    echo "CSV file $S3_OBJECT_KEY ALREADY EXISTS in S3 bucket $BUCKET_NAME."
fi

echo "Removing temporary local CSV file: $LOCAL_CSV_PATH"

# Delete the temporary local CSV file
rm "$LOCAL_CSV_PATH"
echo "Temporary CSV file deleted: $LOCAL_CSV_PATH"

# -----------------------------------------------------------------------------------------------
# ----- Export Terraform variables -----
# -----------------------------------------------------------------------------------------------

# Export ECR repo name as variable for Terraform
export TF_VAR_output_s3_bucket_name="$BUCKET_NAME"
export TF_VAR_output_s3_object_key="$S3_OBJECT_KEY"
export TF_VAR_tfstate_s3_bucket_name="$TF_STATE_S3_BUCKET_NAME"

# Check if the script is running on GitHub Actions and the flag is set to true
if [[ "$RUNNING_ON_GITHUB_ACTION" == "true" ]]; then
    echo "Running on GitHub Actions, exporting environment variables to Github Env..."
    # Export the environment variables to $GITHUB_ENV
    echo "TF_VAR_output_s3_bucket_name=$BUCKET_NAME" >> $GITHUB_ENV
    echo "TF_VAR_output_s3_object_key=$S3_OBJECT_KEY" >> $GITHUB_ENV
    echo "TF_VAR_tfstate_s3_bucket_name=$TF_STATE_S3_BUCKET_NAME" >> $GITHUB_ENV
    echo "Exported TF_VAR_output_s3_bucket_name, TF_VAR_output_s3_object_key, and TF_VAR_tfstate_s3_bucket_name to Github Env"
fi