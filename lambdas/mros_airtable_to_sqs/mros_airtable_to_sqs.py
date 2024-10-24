# Description: This script will pull data from Airtable and save it to S3 as a parquet file
# Usage: python mros_airtable_to_sqs.py
# Author: Angus Watters

# general utility libraries
import os
import re
from datetime import datetime, timedelta
import requests
import json
import time
import hashlib
# import uuid

# pandas and json_normalize for flattening JSON data
import pandas as pd
from pandas import json_normalize

# import awswrangler as wr



# AWS SDK for Python (Boto3) and S3fs for S3 file system support
import boto3
import s3fs

# import the environment variables from the config.py file
# import lambdas.mros_airtable_to_sqs.config
# from config import Config

# environemnt variables
BASE_ID = os.environ.get('BASE_ID')
TABLE_ID = os.environ.get('TABLE_ID')
AIRTABLE_TOKEN = os.environ.get('AIRTABLE_TOKEN')
# S3_BUCKET = os.environ.get('S3_BUCKET')
SQS_QUEUE_URL = os.environ.get('SQS_QUEUE_URL')

# DYNAMODB_TABLE = os.environ.get('DYNAMODB_TABLE')
# DATE = os.environ.get('DATE')

# # DynamoDB client
# dynamodb = boto3.client('dynamodb')

# SQS client
sqs = boto3.client('sqs')

# Construct a list of dates 'n' days before the provided date 'timestamp' (in the format "YYYY-MM-DDTHH:MM:SSZ")
def get_dates_before(timestamp, n):
    # parse input string
    parsed_date = datetime.strptime(timestamp, "%Y-%m-%dT%H:%M:%SZ")

    # output list of dates
    date_list = []

    # Iterate over n days
    for i in range(1, n + 1):
        # Get date i days before the current date
        date_before = parsed_date - timedelta(days=i)
        
        # Format the date as "MM/DD/YY"
        formatted_date = date_before.strftime("%m/%d/%y")

        # Append the formatted date to the list
        date_list.append(formatted_date)

    return date_list

def fetch_airtable_data(date, base_id, table_id, airtable_token):

    # date = DATE_LIST[0]
    # base_id = BASE_ID 
    # table_id = TABLE_ID
    # airtable_token = AIRTABLE_TOKEN
    
    # Initialize an empty list to store all records
    all_records    = []
    offset         = None
    pause_duration = 2  # Initial pause duration in seconds

    print(f"Fetching airtable data for:")
    print(f" - date: {date}")
    print(f" - base_id: {base_id}")
    print(f" - table_id: {table_id}")

    while True:
        # Construct the Airtable API endpoint URL with the offset if available
        url = f"https://api.airtable.com/v0/{base_id}/{table_id}/?filterByFormula=%7Bdate_submitted_utc%7D='{date}'"
        # url = f"https://api.airtable.com/v0/{base_id}/{table_id}/?filterByFormula=%7Bdate_submitted_utc%7D='{date}'"
        # url = f"https://api.airtable.com/v0/{base_id}/{table_id}/?filterByFormula=%7Bdate_submitted_utc%7D='{date}'"
        # url = f"https://api.airtable.com/v0/{base_id}/{table_id}/?filterByFormula=%7BSubmitted%20Date%7D='{date}'"

        if offset:
            print(f"Adding offset to url...")
            url += f"&offset={offset}"

        # Set headers with the Authorization token
        headers = {"Authorization": f"Bearer {airtable_token}"}

        # Make GET request to Airtable API
        response = requests.get(url, headers=headers)

        # Check the response status
        if response.status_code == 200:

            print(f"Successfully request")

            # Successful request
            response_data = response.json()
            records = response_data.get("records")
            
            print(f"Retrieved {len(records)} more records")

            # Extend fetched records list to the all_records list
            all_records.extend(records)

            # # Append fetched records to the all_records list
            # all_records.append(records)

            # Get the offset for the next request
            offset = response_data.get("offset")

            # If no more offset, break the loop
            if not offset:
                print(f"No offset provided, stopping requests")
                print(f"====" * 6)
                break

        elif response.status_code == 429:
            # Too Many Requests error handling
            print(f"Received 429 status code")
            print(f"Too many requests, sleeping for 30 seconds and trying again...")
            time.sleep(30)  # Pause for 30 seconds
            print(f"====" * 6)
            continue
        else:
            # Error handling
            print(f"Error: {response.status_code} - {response.text}")
            break
        
        print(f"Sleeping for {pause_duration} seconds")

        # Pause before making the next request
        time.sleep(pause_duration)

        # Increase the pause duration exponentially for the next request
        pause_duration *= 2

        print(f"====" * 6)

    return all_records

def records_to_dataframe(records_list):
        # records_list = airtable_data.get(DATE_LIST[0])
        # Check if records_list exist
        if records_list:

            # pandas JSON normalize the records data into a pandas dataframe
            df = json_normalize(records_list)
            
            # df.columns
            name_mapping = {
                'id' : 'id',
                'createdTime' : 'createdtime',
                'fields.phase' : 'name',
                'fields.latitude' : 'latitude',
                'fields.user' : 'user',
                'fields.longitude' : 'longitude',
                'fields.time_submitted_local' : 'local_time',
                'fields.date_submitted_local' : 'local_date',
                'fields.time_submitted_utc' : 'submitted_time',
                'fields.date_submitted_utc' : 'submitted_date',
                'fields.comment' : 'comment',
                'fields.datetime_received_pacific' : 'time'
            }

            # Rename columns using the lambda function
            df.rename(columns=name_mapping, inplace=True)

            # df.iloc[0]

            # # make all column names lowercase
            # df.columns = df.columns.str.lower()

            # # remove the 'fields' prefix from the column names, and replace any spaces or special characters with underscores
            # clean_cols_names = lambda x: x.split('.', 1)[-1].replace(' ', '_').replace('[^a-zA-Z0-9_]', '')

            # # Rename columns using the lambda function
            # df.rename(columns=clean_cols_names, inplace=True)

            # required columns in output dataframe
            req_columns = ['id', 'createdtime', 'name', 'latitude', 'user', 'longitude',
                           'submitted_time', 'local_time', 'submitted_date', 'local_date', 'comment', 'time']

            # # template dataframe with the required columns
            # tmp_df = pd.DataFrame(columns=req_columns)
            
            # # df.columns

            # # Merge the DataFrames, ensuring that all desired columns are present
            # df = pd.merge(tmp_df, df, how='outer')

            # Reorder the columns
            df = df[req_columns]
            # df.iloc[0]

            # # Replace special characters with underscores in date variable
            # clean_date = re.sub(r'[\W_]+', '_', date)
            
            # Convert the date column to a datetime object
            df["timestamp"] = pd.to_datetime(df.time)

            # Convert the datetime object to an epoch timestamp
            df['timestamp'] = df['timestamp'].apply(lambda x: x.timestamp())

            # # Add a uuid column for each row
            # df['uuid'] = df.apply(lambda x: uuid.uuid4().hex, axis=1)

            # create a duplicate_id column which is the concatenation of the user and time columns (replacing special characters in "time" with underscores)
            df['duplicate_id'] = df['user'] + "_" + df['time'].apply(lambda x: re.sub(r'[\W_]+', '_', x))

            # Group by 'duplicate_id' and add a 'duplicate_count' column
            df['duplicate_count'] = df.groupby('duplicate_id').cumcount() + 1
            
            # return df.to_dict(orient='records')
            return df

# function to create a hash value of a Python dictionary
def hash_dictionary(dictionary, hash_type="sha256"):
    """
    Create a hash of all the values in a Python dictionary.

    Parameters:
    dictionary (dict): Input dictionary.
    hash_type (str): Hash type to use. Default is "sha256". Other options include "md5". 
            If an invalid hash_type is provided, "sha256" will be used.

    Returns:
    str: Hash value.

    """
    # Convert dictionary to a string representation
    dict_str = str(dictionary)

    # Generate hash value of the string representation
    if hash_type == "sha256":
        hash_value = hashlib.sha256(dict_str.encode('utf-8')).hexdigest()
    elif hash_type == "md5":
        hash_value = hashlib.md5(dict_str.encode('utf-8')).hexdigest()
    else:
        hash_value = hashlib.sha256(dict_str.encode('utf-8')).hexdigest()

    return hash_value

# Lambda handler function
# Uses the date from the event to query data from Airtable API for the two previous days and send each record to SQS
# Lambda is triggered by an EventBridge rule that runs on a schedule (probably daily)
def mros_airtable_to_sqs(event, context):

    curr_time = event['time']

    # curr_time = "2023-11-21T00:00:00Z"
    # curr_time = "2024-01-25T00:00:00Z"
    # curr_time = "2024-01-28T00:00:00Z"
    # curr_time = "2024-10-10T00:00:00Z"

    # 2018-09-19 17:47:12
    print(f"curr_time: {curr_time}")

    # ###### OLD METHOD OF GETTING DATE_LIST for 2 days ago (BELOW) ########
    # ###### OLD METHOD OF GETTING DATE_LIST for 2 days ago (BELOW) ########

    # # Parse the input string
    # parsed_date = datetime.strptime(curr_time, "%Y-%m-%dT%H:%M:%SZ")
    # print(f"parsed_date: {parsed_date}")
    
    # # Get date 1 day before the current date
    # date_one_days_ago = parsed_date - timedelta(days=1)
    # print(f"1 days ago date: {date_one_days_ago}")

    # # Get date 2 day before the current date
    # date_two_days_ago = parsed_date - timedelta(days=2)
    # print(f"2 days ago date: {date_two_days_ago}")

    # # Format the date as "MM/DD/YY"
    # DATE = parsed_date.strftime("%m/%d/%y")

    # # Coerce 1 and 2 days dates to format for querying airtable 
    # DATE_1_DAY_AGO = date_one_days_ago.strftime("%m/%d/%y")
    # DATE_2_DAY_AGO = date_two_days_ago.strftime("%m/%d/%y")

    # print(f"- DATE: {DATE}")
    # print(f"- DATE_1_DAY_AGO: {DATE_1_DAY_AGO}")
    # print(f"- DATE_2_DAY_AGO: {DATE_2_DAY_AGO}")
    
    # # Make a list of dates 
    # DATE_LIST = [DATE_1_DAY_AGO, DATE_2_DAY_AGO]
    # # DATE_LIST = ['01/24/24', '01/23/24', '0010/3212/34134']

    # ###### OLD METHOD OF GETTING DATE_LIST for 2 days ago (ABOVE) ########
    # ###### OLD METHOD OF GETTING DATE_LIST for 2 days ago (ABOVE) ########

    # New method of getting DATE_LIST for 7 days ago (or any number of days with 'n' argument)
    DATE_LIST = get_dates_before(curr_time, 7)

    # temporarily set DATE_LIST to the last two dates in the list ( 6 and 7 days ago )
    # Theorizing that GPM PLP data has some sort of 5 day lag on when the data is 
    # properly uploaded and ready to be accessed
    DATE_LIST = DATE_LIST[-2:]

    print(f"- DATE_LIST: {json.dumps(DATE_LIST)}")

    # Get airtable data for each date in DATE_LIST
    airtable_data = {var: fetch_airtable_data(var, BASE_ID, TABLE_ID, AIRTABLE_TOKEN) for var in DATE_LIST}
    # {var: fetch_airtable_data(var, BASE_ID, TABLE_ID, AIRTABLE_TOKEN) for var in DATE_LIST} 
    # Make a count of the number of records from each day
    record_counts = [i + ": " + str(len(airtable_data[i])) for i in airtable_data]
    print(f"record_counts: {json.dumps(record_counts)}")

    # # Convert each list of airtable jsons to a pandas dataframe
    # record_dfs = {i: records_to_dataframe(airtable_data[i]) for i in airtable_data if airtable_data[i]}

    for i in airtable_data:
        # print(f"i: {i}")
        if airtable_data[i]:
            print(f"Converting airtable list for date '{i}' to dataframe...")
            airtable_data[i] = records_to_dataframe(airtable_data[i])
        else:
            print(f"No records found for date '{i}', Skipping key '{i}'...")
            airtable_data[i] = None

    # [records_to_dataframe(airtable_data[i]) for i in airtable_data if airtable_data[i]]
    # airtable_data.keys()
    # len(airtable_data[DATE_LIST[0]])
    # len(airtable_data[DATE_LIST[1]])

    # Loop through each key in the dictionary 
    for date_key in airtable_data:
        # for date_key in record_dfs:
        print(f"(date_key: {date_key})")

        # Get the dataframe for the given date
        df = airtable_data[date_key]

        if df is not None:
            print(f"Number of rows in df: {len(df)}")
            print(f"Number of columns in df: {len(df.columns)}")

            # Loop through the dataframe and send each record to SQS
            print(f"Adding {len(df)} records to SQS queue")
            for i in range(0, len(df)):
            # for i in range(0, 10):
                
                # print(f"Adding record {i} to SQS queue")

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
                    # 'uuid': str(df["uuid"].iloc[i]),
                    'duplicate_id': str(df["duplicate_id"].iloc[i]),
                    'duplicate_count': str(df["duplicate_count"].iloc[i])
                    # Add other fields as needed
                }
                
                # create a hash of the message body
                message_hash = hash_dictionary(message_body)

                # add the hash to the message body
                message_body['record_hash'] = message_hash

                # print(f"message_body: {message_body}")

                # try to send the message to SQS
                try:
                    # print(f"- Sending message {i} to SQS queue")
                    # Send the message to SQS
                    sqs.send_message(
                        QueueUrl    = SQS_QUEUE_URL,
                        MessageBody = json.dumps(message_body)
                    )
                except Exception as e:
                    print(f"Exception raised from row i {i}\n: {e}")
        
        print(f"====" * 6)

    return

# # lambda handler function (version 1)
# def mros_airtable_to_sqs(event, context):

#     curr_time = event['time']
#     # curr_time = "2023-11-21T00:00:00Z"
#     # curr_time = "2024-01-25T00:00:00Z"

#     # 2018-09-19 17:47:12
#     print(f"curr_time: {curr_time}")
    
#     # Parse the input string
#     parsed_date = datetime.strptime(curr_time, "%Y-%m-%dT%H:%M:%SZ")
#     print(f"parsed_date: {parsed_date}")

#     # Format the date as "MM/DD/YY"
#     DATE = parsed_date.strftime("%m/%d/%y")

#     print(f"DATE: {DATE}")

#     # construct the Airtable API endpoint URL
#     url = f"https://api.airtable.com/v0/{BASE_ID}/{TABLE_ID}/?filterByFormula=%7BSubmitted%20Date%7D='{DATE}'"

#     # set headers with the Authorization token
#     headers = {
#         "Authorization": f"Bearer {AIRTABLE_TOKEN}"
#     }

#     # make GET request to Airtable API
#     response = requests.get(url, headers=headers)

#     # Check the response status
#     if response.status_code == 200:
#         # Successful request
#         response_data = response.json()
#         print("Records:", response_data.get("records"))
#     else:
#         # Error handling
#         print(f"Error: {response.status_code} - {response.text}")

#     # Extract the 'records' field from the JSON response_data
#     records = response_data['records']

#     # pandas JSON normalize the records data into a pandas dataframe
#     df = json_normalize(records)

#     # make all column names lowercase
#     df.columns = df.columns.str.lower()

#     # remove the 'fields' prefix from the column names, and replace any spaces or special characters with underscores
#     clean_cols_names = lambda x: x.split('.', 1)[-1].replace(' ', '_').replace('[^a-zA-Z0-9_]', '')

#     # Rename columns using the lambda function
#     df.rename(columns=clean_cols_names, inplace=True)

#     # required columns in output dataframe
#     req_columns = ['id', 'createdtime', 'name', 'latitude', 'user', 'longitude',
#                        'submitted_time', 'local_time', 'submitted_date', 'local_date', 'comment', 'time']
    
#     # template dataframe with the required columns
#     tmp_df = pd.DataFrame(columns=req_columns)

#     # Merge the DataFrames, ensuring that all desired columns are present
#     df = pd.merge(tmp_df, df, how='outer')

#     # Reorder the columns
#     df = df[req_columns]

#     # Replace special characters with underscores in date variable
#     clean_date = re.sub(r'[\W_]+', '_', DATE)
#     # clean_date = re.sub(r'[^a-zA-Z0-9_]', '_', DATE)

#     # Convert the date column to a datetime object
#     df["timestamp"] = pd.to_datetime(df.time)

#     # Convert the datetime object to an epoch timestamp
#     df['timestamp'] = df['timestamp'].apply(lambda x: x.timestamp())

#     # Add a uuid column for each row
#     df['uuid'] = df.apply(lambda x: uuid.uuid4().hex, axis=1)

#     # create a duplicate_id column which is the concatenation of the user and time columns (reolacing special characters in "time" with underscores)
#     df['duplicate_id'] = df['user'] + "_" + df['time'].apply(lambda x: re.sub(r'[\W_]+', '_', x))

#     # Group by 'duplicate_id' and add a 'duplicate_count' column
#     df['duplicate_count'] = df.groupby('duplicate_id').cumcount() + 1

#     # Loop through the dataframe and send each record to SQS
#     # for i in range(0, 20):
#     for i in range(0, len(df)):
        
#         print(f"Adding record {i} to SQS queue")

#         # Construct the message body
#         message_body = {
#             'id': str(df["id"].iloc[i]),
#             'timestamp': str(df["timestamp"].iloc[i]),
#             'createdtime': str(df["createdtime"].iloc[i]),
#             'name': str(df["name"].iloc[i]),
#             'latitude': str(df["latitude"].iloc[i]),
#             'user': str(df["user"].iloc[i]),
#             'longitude': str(df["longitude"].iloc[i]),
#             'submitted_time': str(df["submitted_time"].iloc[i]),
#             'local_time': str(df["local_time"].iloc[i]),
#             'submitted_date': str(df["submitted_date"].iloc[i]),
#             'local_date': str(df["local_date"].iloc[i]),
#             'comment': str(df["comment"].iloc[i]),
#             'time': str(df["time"].iloc[i]),
#             'uuid': str(df["uuid"].iloc[i]),
#             'duplicate_id': str(df["duplicate_id"].iloc[i]),
#             'duplicate_count': str(df["duplicate_count"].iloc[i])
#             # Add other fields as needed
#         }

#         print(f"message_body: {message_body}")

#         # try to send the message to SQS
#         try:
#             # Send the message to SQS
#             sqs.send_message(
#                 QueueUrl    = SQS_QUEUE_URL,
#                 MessageBody = json.dumps(message_body)
#             )
#         except Exception as e:
#             print(f"Exception raised from row i {i}\n: {e}")

#         # # Send the message to SQS
#         # sqs.send_message(
#         #     QueueUrl    = SQS_QUEUE_URL,
#         #     MessageBody = json.dumps(message_body)
#         # )

#         print(f"=====================")

#     # # Save the dataframe to a parquet/CSV file in S3
#     # s3_object = f"{S3_BUCKET}/raw/mros_airtable_{clean_date}.csv"
#     # # local_object = f"/Users/anguswatters/Desktop/mros_airtable_{clean_date}.csv"
#     # # s3_object = f"{S3_BUCKET}/raw/mros_airtable_{clean_date}.parquet"

#     # print(f"s3_object: {s3_object}")

#     # print(f"Saving dataframe to {s3_object}")
#     # print(f"df.shape: {df.shape}")

#     # # # save the dataframe as a parquet to S3
#     # df.to_csv(s3_object)

#     # wr.s3.to_parquet(df, s3_object)
#     # df.to_parquet(s3_object)

#     return


# def fetch_airtable_data(date, base_id, table_id, airtable_token):
#     # date = DATE_1_DAY_AGO
#     # base_id = BASE_ID
#     # table_id = TABLE_ID
#     # airtable_token = AIRTABLE_TOKEN

#     # construct the Airtable API endpoint URL
#     url = f"https://api.airtable.com/v0/{base_id}/{table_id}/?filterByFormula=%7BSubmitted%20Date%7D='{date}'"

#     # set headers with the Authorization token
#     headers = {
#         "Authorization": f"Bearer {airtable_token}"
#     }

#     # make GET request to Airtable API
#     response = requests.get(url, headers=headers)

#     # Check the response status
#     if response.status_code == 200:
        
#         # Successful request
#         response_data = response.json()
#         records = response_data.get("records")

#         # this needs to be passed to the next request until no more offset is given 
#         offset  = response_data.get("offset")
        
#         # Check if records exist
#         if records:
#             # pandas JSON normalize the records data into a pandas dataframe
#             df = json_normalize(records)

#             # make all column names lowercase
#             df.columns = df.columns.str.lower()

#             # remove the 'fields' prefix from the column names, and replace any spaces or special characters with underscores
#             clean_cols_names = lambda x: x.split('.', 1)[-1].replace(' ', '_').replace('[^a-zA-Z0-9_]', '')

#             # Rename columns using the lambda function
#             df.rename(columns=clean_cols_names, inplace=True)

#             # required columns in output dataframe
#             req_columns = ['id', 'createdtime', 'name', 'latitude', 'user', 'longitude',
#                            'submitted_time', 'local_time', 'submitted_date', 'local_date', 'comment', 'time']

#             # template dataframe with the required columns
#             tmp_df = pd.DataFrame(columns=req_columns)

#             # Merge the DataFrames, ensuring that all desired columns are present
#             df = pd.merge(tmp_df, df, how='outer')

#             # Reorder the columns
#             df = df[req_columns]

#             # Replace special characters with underscores in date variable
#             clean_date = re.sub(r'[\W_]+', '_', date)
            
#             # Convert the date column to a datetime object
#             df["timestamp"] = pd.to_datetime(df.time)

#             # Convert the datetime object to an epoch timestamp
#             df['timestamp'] = df['timestamp'].apply(lambda x: x.timestamp())

#             # Add a uuid column for each row
#             df['uuid'] = df.apply(lambda x: uuid.uuid4().hex, axis=1)

#             # create a duplicate_id column which is the concatenation of the user and time columns (replacing special characters in "time" with underscores)
#             df['duplicate_id'] = df['user'] + "_" + df['time'].apply(lambda x: re.sub(r'[\W_]+', '_', x))

#             # Group by 'duplicate_id' and add a 'duplicate_count' column
#             df['duplicate_count'] = df.groupby('duplicate_id').cumcount() + 1
            
#             # return df.to_dict(orient='records')
#             return df
#         else:
#             print("No records found for the given date, returning None")
#             return None
#     else:
#         # Error handling
#         print(f"Error: {response.status_code} - {response.text}")
#         print("---> Returning None")
#         return None
