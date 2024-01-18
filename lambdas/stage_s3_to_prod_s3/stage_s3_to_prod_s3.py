# Description: This script will pull data from Airtable and save it to S3 as a parquet file
# Usage: python airtable_to_sqs.py
# Author: Angus Watters

# general utility libraries
import os
import re
from datetime import datetime
import requests
import json

# pandas and json_normalize for flattening JSON data
import pandas as pd
from pandas import json_normalize
# import awswrangler as wr

# AWS SDK for Python (Boto3) and S3fs for S3 file system support
import boto3
import s3fs

# import the environment variables from the config.py file
# import lambdas.stage_s3_to_prod_s3.config
# from .config import Config

# environemnt variables

# Full bucket URIs
S3_BUCKET = os.environ.get('S3_BUCKET')
S3_STAGING_BUCKET = os.environ.get('S3_STAGING_BUCKET')
S3_PROD_BUCKET = os.environ.get('S3_PROD_BUCKET')

# Bucket names
S3_STAGING_BUCKET_NAME = os.environ.get('S3_STAGING_BUCKET_NAME')
S3_PROD_BUCKET_NAME = os.environ.get('S3_PROD_BUCKET_NAME')

# S3 client
s3 = boto3.client('s3')
    
# lambda handler function
def stage_s3_to_prod_s3(event, context):

    # print(f"event: {event}")
    print(f"- S3_BUCKET: {S3_BUCKET}")
    print(f"- S3_STAGING_BUCKET: {S3_STAGING_BUCKET}")
    print(f"- S3_PROD_BUCKET: {S3_PROD_BUCKET}")

    # get a list of objects in the staging bucket
    response = s3.list_objects(Bucket=S3_STAGING_BUCKET_NAME)

    # get a list of JSON (".json") files in the staging bucket
    json_files = [obj['Key'] for obj in response.get('Contents', []) if obj['Key'].lower().endswith('.json')]


    json_list = []

    # iterate through the list of JSON files
    for json_file in json_files:
        print(f"json_file: {json_file}")

        # json_content = read_json_from_s3(bucket_name, json_file)

        # get the object from S3
        json_data = s3.get_object(Bucket=S3_STAGING_BUCKET_NAME, Key=json_file)

        # get the contents of the file
        obj_content = json.load(json_data['Body'])

        json_list.append(json.loads(obj_content[0])[0])

        print(f"==================")

    # convert the list of JSON objects (dictionaries) to a Pandas DataFrame
    df = pd.DataFrame(json_list)

    # clean day date to use in the filename
    clean_date = df.submitted_date.values[0].replace("/", "_")

    # Save the dataframe to a parquet/CSV file in S3
    s3_object = f"{S3_PROD_BUCKET}/daily/mros_observations_{clean_date}.csv"
    # local_object = f"/Users/anguswatters/Desktop/mros_airtable_{clean_date}.csv"
    # s3_object = f"{S3_BUCKET}/raw/mros_airtable_{clean_date}.parquet"

    print(f"s3_object: {s3_object}")

    print(f"Saving dataframe to {s3_object}")
    print(f"df.shape: {df.shape}")

    # # save the dataframe as a parquet to S3
    df.to_csv(s3_object)

    return