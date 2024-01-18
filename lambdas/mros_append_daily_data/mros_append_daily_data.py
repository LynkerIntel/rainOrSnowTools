# Description: Lambda function runs when new messages appear in SQS queue and takes the S3 event notification info from the message,
#  downloads the new input dataset, and appends it to the existing stationary CSV file in S3.
# Usage: python airtable_to_sqs.py
# Author: Angus Watters

# general utility libraries
import os
import re
from datetime import datetime
import json

# AWS SDK for Python (Boto3) and S3fs for S3 file system support
import boto3
import s3fs
import pandas as pd

# Environment variables

# Full bucket URIs
OUTPUT_S3_BUCKET  = os.environ.get('OUTPUT_S3_BUCKET')
OUTPUT_OBJECT_KEY = os.environ.get('OUTPUT_OBJECT_KEY')

# S3 client
s3 = boto3.client('s3')
    
# lambda handler function
def mros_append_daily_data(event, context):
    
    # get the bucket name and object key from the event
    INPUT_S3_BUCKET = event['Records'][0]['s3']['bucket']['name']
    INPUT_OBJECT_KEY = event['Records'][0]['s3']['object']['key']

    # print(f"event: {event}")
    print(f"- INPUT_S3_BUCKET: {INPUT_S3_BUCKET}")
    print(f"- INPUT_OBJECT_KEY: {INPUT_OBJECT_KEY}")
    print(f"- OUTPUT_S3_BUCKET: {OUTPUT_S3_BUCKET}")
    print(f"- OUTPUT_OBJECT_KEY: {OUTPUT_OBJECT_KEY}")

    # download the INPUT file from S3
    try:
        s3.download_file(INPUT_S3_BUCKET, INPUT_OBJECT_KEY, f'/tmp/{INPUT_OBJECT_KEY}')
    except Exception as e:
        print(f"Exception downloading INPUT file from S3: {e}")
        print(f"- Problem INPUT_OBJECT_KEY: {INPUT_OBJECT_KEY}")

    # download the OUTPUT file from S3
    try:
        s3.download_file(OUTPUT_S3_BUCKET, OUTPUT_OBJECT_KEY, f'/tmp/{OUTPUT_OBJECT_KEY}')
    except Exception as e:
        print(f"Exception downloading OUTPUT file from S3: {e}")
        print(f"- Problem OUTPUT_OBJECT_KEY: {OUTPUT_OBJECT_KEY}")

    # read the input and output files into dataframes
    output_df = pd.read_csv(f'/tmp/{OUTPUT_OBJECT_KEY}')
    input_df  = pd.read_csv(f'/tmp/{INPUT_OBJECT_KEY}')

    print(f"output_df.shape: {output_df.shape}")
    print(f"len(output_df): {len(output_df)}")
    print(f"input_df.shape: {input_df.shape}")
    print(f"len(input_df): {len(input_df)}")

    print(f"Concatenating dataframes...")

    # Concatenate the input file to the output file
    output_df = pd.concat([output_df, input_df])

    # Create the S3 URI for the output CSV file
    UPDATED_S3_OBJECT_KEY = f"s3://{OUTPUT_S3_BUCKET}/{OUTPUT_OBJECT_KEY}"

    print(f"UPDATED_S3_OBJECT_KEY: {UPDATED_S3_OBJECT_KEY}")
    print(f"Saving dataframe to {UPDATED_S3_OBJECT_KEY}")
    print(f"FINAL output_df.shape: {output_df.shape}")
    print(f"FINAL len(output_df): {len(output_df)}")
    # output_df.to_csv(f'/tmp/{OUTPUT_OBJECT_KEY}', index=False)
    
    try:
        # # save the dataframe as a parquet to S3
        output_df.to_csv(UPDATED_S3_OBJECT_KEY)
    except Exception as e:
        print(f"Exception saving dataframe to S3: {e}")
        print(f"- Problem INPUT_OBJECT_KEY: {INPUT_OBJECT_KEY}")
        print(f"- Problem UPDATED_S3_OBJECT_KEY: {UPDATED_S3_OBJECT_KEY}")
        print(f"-----> RAISING EXCEPTION ON UPLOAD TO S3 <-----")
        raise

    print(f"===" * 5)
    # # append the input file to the output file
    # with open('/tmp/input.csv', 'r') as f:
    #     with open(f'/tmp/{OUTPUT_OBJECT_KEY}', 'a') as f1:
    #         for line in f:
    #             f1.write(line)

    return