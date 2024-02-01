# Description: Lambda function runs when new messages appear in SQS queue and takes the S3 event notification info from the message,
#  downloads the new input dataset, and appends it to the existing stationary CSV file in S3 and writes a new CSV and new parquet file back to the output S3 bucket.
# Usage: python mros_append_daily_data.py
# Author: Angus Watters

# general utility libraries
import os
import re
from datetime import datetime
import json

# # AWS SDK for Python (Boto3) and S3fs for S3 file system support
# import boto3
# import s3fs
# import pandas as pd

import awswrangler as wr

# Environment variables

# Full bucket URIs
OUTPUT_S3_BUCKET  = os.environ.get('OUTPUT_S3_BUCKET')
OUTPUT_OBJECT_KEY = os.environ.get('OUTPUT_OBJECT_KEY')

# lambda handler function
def mros_append_daily_data(event, context):
    print(f"===" * 5)
    print(f"event: {event}")
    print(f"===" * 5)
    
    # Get the SQS event message
    message = event['Records'][0]

    print(f"message: {message}")

    print(f"Extracting message body...")

    # Get the SQS event message body
    message_body = message["body"]

    print(f"message_body: {message_body}")
    print(f"Converting 'message_body' from JSON to dict...")

    message_body = json.loads(message_body)

    print(f"Extracting 'inner_json' from message_body...")

    inner_json = message_body["Message"]

    print(f"- inner_json: {inner_json}")
    print(f"Converting 'inner_json' from JSON to dict...")

    # Convert the SQS event message from JSON to dict
    inner_json = json.loads(inner_json)

    print(f"Extracting s3_event from inner_json...")
    s3_event = inner_json["Records"][0]

    print(f"--> s3_event: {s3_event}")

    # get the bucket name and object key from the event
    INPUT_S3_BUCKET  = s3_event["s3"]["bucket"]["name"]
    INPUT_OBJECT_KEY = s3_event["s3"]["object"]["key"]
    INPUT_S3_URI = f"s3://{INPUT_S3_BUCKET}/{INPUT_OBJECT_KEY}"
    OUTPUT_S3_URI = f"s3://{OUTPUT_S3_BUCKET}/{OUTPUT_OBJECT_KEY}"

    print(f"- INPUT_S3_BUCKET: {INPUT_S3_BUCKET}")
    print(f"- INPUT_OBJECT_KEY: {INPUT_OBJECT_KEY}")
    print(f"- INPUT_S3_URI: {INPUT_S3_URI}")
    print(f"- OUTPUT_S3_BUCKET: {OUTPUT_S3_BUCKET}")
    print(f"- OUTPUT_OBJECT_KEY: {OUTPUT_OBJECT_KEY}")
    print(f"- OUTPUT_S3_URI: {OUTPUT_S3_URI}")

    # Read the CSV file into a Pandas dataframe
    try:
        # Read the CSV file into a Pandas dataframe
        input_df = wr.s3.read_csv(INPUT_S3_URI)
        print(f"CSV file read into Pandas dataframe")
    except Exception as e:
        print(f"Exception reading CSV file into Pandas dataframe: {e}")
        print(f"Problem INPUT_S3_URI: {INPUT_S3_URI}")
        raise e
    
    try:
        # Read the CSV file into a Pandas dataframe
        output_df = wr.s3.read_csv(OUTPUT_S3_URI)
        print(f"CSV file read into Pandas dataframe")
    except Exception as e:
        print(f"Exception reading CSV file into Pandas dataframe: {e}")
        print(f"Problem OUTPUT_S3_URI: {OUTPUT_S3_URI}")
        raise e
    
    # Print out INPUT / OUTPUT dataframe dimensions
    print(f"- input_df.shape: {input_df.shape}")
    print(f"- Number of columns in input_df: {len(input_df.columns)}")
    print(f"- Number of rows in input_df: {len(input_df)}")
    print(f"- output_df.shape: {output_df.shape}")
    print(f"- Number of columns in output_df: {len(output_df.columns)}")
    print(f"- Number of rows in output_df: {len(output_df)}")
    
    print(f"Number of rows in input_df: {len(input_df)} (BEFORE removing duplicate record_hash values)")

    # Remove rows of the "input_df" that have a "duplicate_count_id" that is already in the "output_df"
    # This is to prevent duplicate rows from being added to the output file
    input_df = input_df[-input_df["record_hash"].isin(output_df["record_hash"])]

    print(f"Number of rows in input_df: {len(input_df)} (AFTER removing duplicate record_hash values)")
    print(f"Concatenating dataframes...")

    # Concatenate the input file to the output file\
    output_df = wr.pandas.concat([output_df, input_df], axis=0)
    # output_df = pd.concat([output_df, input_df], axis=0)

    print(f"FINAL OUTPUT dataframe dimensions:")
    print(f"--> (Final) output_df.shape: {output_df.shape}")
    print(f"--> (Final) Number of columns in output_df: {len(output_df.columns)}")
    print(f"--> (Final) Number of rows in output_df: {len(output_df)}")

    # Create the S3 URI for the output CSV and PARQUET files
    UPDATED_S3_CSV_URI = f"s3://{OUTPUT_S3_BUCKET}/{OUTPUT_OBJECT_KEY}"
    UPDATED_S3_PARQUET_URI = f"s3://{OUTPUT_S3_BUCKET}/{OUTPUT_OBJECT_KEY.replace('.csv', '.parquet')}"

    print(f"- UPDATED_S3_CSV_URI: {UPDATED_S3_CSV_URI}")
    print(f"- UPDATED_S3_PARQUET_URI: {UPDATED_S3_PARQUET_URI}")
    print(f"Saving dataframe as CSV to {UPDATED_S3_CSV_URI}")
    print(f"Saving dataframe as PARQUET to {UPDATED_S3_PARQUET_URI}")

    # write the dataframe to S3 as CSV
    try:
        # # save the dataframe as a CSV to S3
        wr.s3.to_csv(output_df, UPDATED_S3_CSV_URI, index = False)
    except Exception as e:
        print(f"Exception saving dataframe to S3: {e}")
        print(f"- Problem INPUT_S3_URI: {INPUT_S3_URI}")
        print(f"- Problem OUTPUT_S3_URI: {OUTPUT_S3_URI}")
        print(f"- Problem UPDATED_S3_CSV_URI: {UPDATED_S3_CSV_URI}")
        print(f"-----> RAISING EXCEPTION ON CSV UPLOAD TO S3 <-----")
        raise e
    
    # write the dataframe to S3 as Parquet
    try:
        # # save the dataframe as a parquet to S3
        wr.s3.to_parquet(output_df, UPDATED_S3_PARQUET_URI, index = False)
        # wr.s3.to_parquet(output_df, UPDATED_S3_PARQUET_URI, index = False, boto3_session=boto_session)

    except Exception as e:
        print(f"Exception saving dataframe to S3: {e}")
        print(f"- Problem INPUT_S3_URI: {INPUT_S3_URI}")
        print(f"- Problem OUTPUT_S3_URI: {OUTPUT_S3_URI}")
        print(f"- Problem UPDATED_S3_PARQUET_URI: {UPDATED_S3_PARQUET_URI}")
        print(f"-----> RAISING EXCEPTION ON PARQUET UPLOAD TO S3 <-----")
        raise e
    
    print(f"===" * 5)

    return {"statusCode": 200, "body": json.dumps({"message": "Daily data added and data written as CSV and Parquet files to S3"})}