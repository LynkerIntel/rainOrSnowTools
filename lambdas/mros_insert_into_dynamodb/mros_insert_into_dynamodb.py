# Description: Lambda function runs when new messages appear in SQS queue and takes the S3 event notification info from the message,
#  downloads the new input dataset, and appends it to the existing stationary CSV file in S3.
# Usage: python airtable_to_sqs.py
# Author: Angus Watters

# general utility libraries
import os
import re
from datetime import datetime
import json
from decimal import Decimal

# # AWS SDK for Python (Boto3) and S3fs for S3 file system support
# import boto3
# import s3fs
# import pandas as pd

# AWS SDK for Pandas
import awswrangler as wr

# Environment variables

# Full bucket URIs
DYNAMODB_TABLE  = os.environ.get('DYNAMODB_TABLE')

# # S3 client
# s3 = boto3.client('s3')

# # DynamoDB client
# dynamodb = boto3.client('dynamodb')

def float_to_decimal(num):
    return Decimal(str(num))

def pandas_to_dynamodb(df, table_name):

    df = df.fillna(0)
    
    # convert any floats to decimals
    for i in df.columns:

        datatype = df[i].dtype
        # print(f"i: {i}")
        # print(f"datatype: {datatype}")

        if datatype == 'float64':
            # print(f"datatype is float64")
            df[i] = df[i].apply(float_to_decimal)
    # write to dynamodb
    wr.dynamodb.put_df(df=df, table_name=table_name)
        # print(f"===" * 5)
    return df 

# lambda handler function
def mros_insert_into_dynamodb(event, context):

    print(f"===" * 5)
    print(f"event: {event}")
    print(f"===" * 5)

    print(f"Extracting SNS message from event...")

    # get the SNS message from the event
    sns_message = json.loads(event['Records'][0]['Sns']['Message'])
    
    print(f"---> sns_message: {sns_message}")

    print(f"Extracting S3 bucket name and object key from SNS message...")

    # Extract S3 bucket name and object key from SNS event
    S3_BUCKET     = sns_message['Records'][0]['s3']['bucket']['name']
    S3_OBJECT_KEY = sns_message['Records'][0]['s3']['object']['key']

    print(f"- S3_BUCKET: {S3_BUCKET}")
    print(f"- S3_OBJECT_KEY: {S3_OBJECT_KEY}")
    print(f"Extracting S3 object filename from S3 object key...")
    # Get the S3 object filename
    S3_OBJ_FILENAME = os.path.basename(S3_OBJECT_KEY)

    print(f"- S3_OBJ_FILENAME: {S3_OBJ_FILENAME}")

    # Create local file path in /tmp
    local_file_path = f"/tmp/{S3_OBJ_FILENAME}"

    print(f"- local_file_path: {local_file_path}")

    # Download the S3 object
    print(f"Downloading S3 object...")
    
    S3_FULL_PATH = f"s3://{S3_BUCKET}/{S3_OBJECT_KEY}"

    print(f"- S3_FULL_PATH: {S3_FULL_PATH}")
    print(f"Reading CSV file into Pandas dataframe...")
    try:
        # s3.download_file(S3_BUCKET, S3_OBJECT_KEY, local_file_path)
        # wr.s3.download(path=S3_FULL_PATH, local_file=local_file_path)
        df = wr.s3.read_csv(S3_FULL_PATH)
    except Exception as e:
        print(f"Exception downloading S3_OBJECT_KEY file from S3: {e}")
        print(f"- Problem S3_FULL_PATH: {S3_FULL_PATH}")
        print(f"- Problem S3_OBJECT_KEY: {S3_OBJECT_KEY}")
        print(f"- Problem S3_OBJ_FILENAME: {S3_OBJ_FILENAME}")
        print(f"- Problem local_file_path: {local_file_path}")

    # print(f"Reading CSV file into Pandas dataframe...")
    # # Read the CSV file into a Pandas dataframe
    # df = pd.read_csv(local_file_path)

    print(f"df.shape: {df.shape}")
    print(f"Number of rows in dataframe: {len(df)}")
    print(f"Number of columns in dataframe: {len(df.columns)}")

    print(f"Attempting to write dataframe to DynamoDB table...")

    # batch write the dataframe to DynamoDB
    pandas_to_dynamodb(df, DYNAMODB_TABLE)

    return {
        'statusCode': 200,
        'body': json.dumps('Lambda function executed successfully!')
    }


# # function to make a DynamoDB item and add a status code and "epoch_time" timestamp attribute. 
# # Any None values are converted to empty strings
# def make_dynamodb_item(json_object):

#     # set any None values to empty strings
#     for key, value in json_object.items():
#         if value is None:
#             json_object[key] = ""

#     # get the current time
#     current_time = datetime.now()

#     # convert the current datetime object to epoch time integer
#     epoch_time = int(current_time.timestamp())

#     # initialize an empty dictionary for ddb_item
#     ddb_item = {}
#     # ddb_item = {"url": {"S": origin_json["url"]}}
#     # ddb_item = {"uid": {"S": origin_json["uid"]}}

#     # iterate through keys in origin_json and add them to ddb_item
#     for key, value in json_object.items():
#         ddb_item[key] = {"S": str(value)}
    
#     ddb_item["epoch_time"] = {'N': str(epoch_time)}

#     return ddb_item

# # function that takes a pandas dataframe and generates a list of jsons that can be used to make dynamodb items
# def make_dynamodb_items(df):

#     # initialize an empty list
#     dynamodb_items = []

#     # iterate through columns in the dataframe and convert any float64 columns to Decimal
#     for i in df.columns:
#         print(f"i: {i}")
#         print(f"df[i].dtype: {df[i].dtype}")
#         if df[i].dtype == 'float64':
#             print(f"---> datatype is float64")
#             df[i] = df[i].apply(float_to_decimal)
#         print(f"===" * 5)

#     # Iterate over rows, convert each row to a dictionary, and save as JSON
#     for index, row in df.iterrows():
#         print(f"Processing row {index}...")
#         print(f"row: {row}")

#         # Convert the row to a dictionary
#         row_dict = row.to_dict()

#         # # get the datatype of the current column
#         # datatype = df[i].dtype

#         # print(f"datatype: {datatype}")

#         # if datatype == 'float64':
#         #     print(f"---> datatype is float64")
#             # df[i] = df[i].apply(float_to_decimal)
        
#         # make a dynamodb item from the row dictionary
#         dynamodb_item = make_dynamodb_item(row_dict)

#         # append the dynamodb item to the list
#         dynamodb_items.append(dynamodb_item)
    
#     return dynamodb_items