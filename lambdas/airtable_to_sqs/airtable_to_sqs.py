# Description: This script will pull data from Airtable and save it to S3 as a parquet file
# Usage: python airtable_to_sqs.py
# Author: Angus Watters

# general utility libraries
import os
import re
from datetime import datetime
import requests
import json
import time

# pandas and json_normalize for flattening JSON data
import pandas as pd
from pandas import json_normalize
# import awswrangler as wr

# AWS SDK for Python (Boto3) and S3fs for S3 file system support
import boto3
import s3fs

# import the environment variables from the config.py file
# import lambdas.airtable_to_sqs.config
# from config import Config

# environemnt variables
BASE_ID = os.environ.get('BASE_ID')
TABLE_ID = os.environ.get('TABLE_ID')
AIRTABLE_TOKEN = os.environ.get('AIRTABLE_TOKEN')
S3_BUCKET = os.environ.get('S3_BUCKET')
SQS_QUEUE_URL = os.environ.get('SQS_QUEUE_URL')

# DYNAMODB_TABLE = os.environ.get('DYNAMODB_TABLE')
# DATE = os.environ.get('DATE')

# # DynamoDB client
# dynamodb = boto3.client('dynamodb')

# SQS client
sqs = boto3.client('sqs')

# lambda handler function
def airtable_to_sqs(event, context):

    curr_time = event['time']
    # curr_time = "2023-11-21T00:00:00Z"
    # curr_time = "2023-12-01T00:00:00Z"

    # 2018-09-19 17:47:12
    print(f"curr_time: {curr_time}")
    
    # Parse the input string
    parsed_date = datetime.strptime(curr_time, "%Y-%m-%dT%H:%M:%SZ")
    print(f"parsed_date: {parsed_date}")
    
    # Format the date as "MM/DD/YY"
    DATE = parsed_date.strftime("%m/%d/%y")
    print(f"DATE: {DATE}")

    # construct the Airtable API endpoint URL
    url = f"https://api.airtable.com/v0/{BASE_ID}/{TABLE_ID}/?filterByFormula=%7BSubmitted%20Date%7D='{DATE}'"

    # set headers with the Authorization token
    headers = {
        "Authorization": f"Bearer {AIRTABLE_TOKEN}"
    }

    # make GET request to Airtable API
    response = requests.get(url, headers=headers)

    # Check the response status
    if response.status_code == 200:
        # Successful request
        data = response.json()
        print("Records:", data.get("records"))
    else:
        # Error handling
        print(f"Error: {response.status_code} - {response.text}")

    # Extract the 'records' field from the JSON data
    records = data['records']

    # pandas JSON normalize the records data into a pandas dataframe
    df = json_normalize(records)

    # make all column names lowercase
    df.columns = df.columns.str.lower()

    # remove the 'fields' prefix from the column names, and replace any spaces or special characters with underscores
    clean_cols_names = lambda x: x.split('.', 1)[-1].replace(' ', '_').replace('[^a-zA-Z0-9_]', '')

    # Rename columns using the lambda function
    df.rename(columns=clean_cols_names, inplace=True)

    # required columns in output dataframe
    req_columns = ['id', 'createdtime', 'name', 'latitude', 'user', 'longitude',
                       'submitted_time', 'local_time', 'submitted_date', 'local_date', 'comment', 'time']
    
    # template dataframe with the required columns
    tmp_df = pd.DataFrame(columns=req_columns)

    # Merge the DataFrames, ensuring that all desired columns are present
    df = pd.merge(tmp_df, df, how='outer')

    # Reorder the columns
    df = df[req_columns]

    # Replace special characters with underscores in date variable
    clean_date = re.sub(r'[\W_]+', '_', DATE)
    # clean_date = re.sub(r'[^a-zA-Z0-9_]', '_', DATE)

    # Convert the date column to a datetime object
    df["timestamp"] = pd.to_datetime(df.time)

    # Convert the datetime object to an epoch timestamp
    df['timestamp'] = df['timestamp'].apply(lambda x: x.timestamp())

    # # # Loop through the dataframe and save each row to S3
    # for i in range(0, len(df)):
    #     i = 0
    #     # get the id for the current row
    #     print(f"i: {i}")
    #     print(f"df['id'].iloc[i]: {df['id'].iloc[i]}")

    #     # Call the function to process the row
    #     exp_backoff_dynamodb_put(
    #         df             = df, 
    #         i              = i, 
    #         dynamodb_table = DYNAMODB_TABLE, 
    #         max_retries    = 2, 
    #         base_delay     = 1,
    #         max_delay      = 16
    #         )
        
    #     print(f"=====================")

    print(f"df.shape: {df.shape}")

    # Loop through the dataframe and send each record to SQS
    for i in range(0, 20):
    # for i in range(0, len(df)):
        
        print(f"Adding record {i} to SQS queue")

        # Construct the message body
        message_body = {
            'id': str(df["id"].iloc[i]),
            'timestamp': str(df["timestamp"].iloc[i]),
            'createdtime': str(df["createdtime"].iloc[i]),
            'name': str(df["name"].iloc[i]),
            'latitude': str(df["latitude"].iloc[i]),
            'user': str(df["user"].iloc[i]),
            'longitude': str(df["longitude"].iloc[i]),
            'submitted_time': str(df["submitted_time"].iloc[i]),
            'local_time': str(df["local_time"].iloc[i]),
            'submitted_date': str(df["submitted_date"].iloc[i]),
            'local_date': str(df["local_date"].iloc[i]),
            'comment': str(df["comment"].iloc[i]),
            'time': str(df["time"].iloc[i]),
            # Add other fields as needed
        }

        # Send the message to SQS
        sqs.send_message(
            QueueUrl    = SQS_QUEUE_URL,
            MessageBody = json.dumps(message_body)
        )

        print(f"=====================")

    # # Save the dataframe to a parquet/CSV file in S3
    # s3_object = f"{S3_BUCKET}/raw/mros_airtable_{clean_date}.csv"
    # # local_object = f"/Users/anguswatters/Desktop/mros_airtable_{clean_date}.csv"
    # # s3_object = f"{S3_BUCKET}/raw/mros_airtable_{clean_date}.parquet"

    # print(f"s3_object: {s3_object}")

    # print(f"Saving dataframe to {s3_object}")
    # print(f"df.shape: {df.shape}")

    # # # save the dataframe as a parquet to S3
    # df.to_csv(s3_object)

    # wr.s3.to_parquet(df, s3_object)
    # df.to_parquet(s3_object)

    return