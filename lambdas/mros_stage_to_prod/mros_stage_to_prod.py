# Description: This script will pull data from Airtable and save it to S3 as a parquet file
# Usage: python mros_stage_to_prod.py
# Author: Angus Watters

# general utility libraries
import os
import re
from datetime import datetime
import json
import uuid
import time
import hashlib

# pandas and json_normalize for flattening JSON data
import pandas as pd
from pandas import json_normalize
# import awswrangler as wr

# AWS SDK for Python (Boto3) and S3fs for S3 file system support
import boto3
import s3fs

# import the environment variables from the config.py file
# import lambdas.mros_stage_to_prod.config
# from .config import Config

# Environment variables

# # Full bucket URIs
# S3_BUCKET = os.environ.get('S3_BUCKET')
# S3_STAGING_BUCKET = os.environ.get('S3_STAGING_BUCKET')
# S3_PROD_BUCKET = os.environ.get('S3_PROD_BUCKET')

# # Bucket names
# S3_STAGING_BUCKET_NAME = os.environ.get('S3_STAGING_BUCKET_NAME')
# S3_PROD_BUCKET_NAME = os.environ.get('S3_PROD_BUCKET_NAME')

# Environment variables
S3_STAGE_BUCKET     = os.environ.get('S3_STAGE_BUCKET')
S3_PROD_BUCKET      = os.environ.get('S3_PROD_BUCKET')
S3_STAGE_BUCKET_URI = os.environ.get('S3_STAGE_BUCKET_URI')
S3_PROD_BUCKET_URI  = os.environ.get('S3_PROD_BUCKET_URI')

# S3 client
s3 = boto3.client('s3')

"""
Copyright (C) 2008 Leonard Norrgard <leonard.norrgard@gmail.com>
Copyright (C) 2015 Leonard Norrgard <leonard.norrgard@gmail.com>

The below code (the decode_exactly(), decode(), and encode() functions) are part of the Geohash package  all credit goes to: Leonard Norrgard <leonard.norrgard@gmail.com>

Geohash is free software: you can redistribute it and/or modify it
under the terms of the GNU Affero General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Geohash is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
License for more details.

You should have received a copy of the GNU Affero General Public
License along with Geohash.  If not, see
<http://www.gnu.org/licenses/>.
"""

from math import log10

#  Note: the alphabet in geohash differs from the common base32
#  alphabet described in IETF's RFC 4648
#  (http://tools.ietf.org/html/rfc4648)

__base32 = '0123456789bcdefghjkmnpqrstuvwxyz'
__decodemap = { }
for i in range(len(__base32)):
    __decodemap[__base32[i]] = i
del i

def decode_exactly(geohash):
    """
    Decode the geohash to its exact values, including the error
    margins of the result.  Returns four float values: latitude,
    longitude, the plus/minus error for latitude (as a positive
    number) and the plus/minus error for longitude (as a positive
    number).
    """
    lat_interval, lon_interval = (-90.0, 90.0), (-180.0, 180.0)
    lat_err, lon_err = 90.0, 180.0
    is_even = True
    for c in geohash:
        cd = __decodemap[c]
        for mask in [16, 8, 4, 2, 1]:
            if is_even: # adds longitude info
                lon_err /= 2
                if cd & mask:
                    lon_interval = ((lon_interval[0]+lon_interval[1])/2, lon_interval[1])
                else:
                    lon_interval = (lon_interval[0], (lon_interval[0]+lon_interval[1])/2)
            else:      # adds latitude info
                lat_err /= 2
                if cd & mask:
                    lat_interval = ((lat_interval[0]+lat_interval[1])/2, lat_interval[1])
                else:
                    lat_interval = (lat_interval[0], (lat_interval[0]+lat_interval[1])/2)
            is_even = not is_even
    lat = (lat_interval[0] + lat_interval[1]) / 2
    lon = (lon_interval[0] + lon_interval[1]) / 2
    return lat, lon, lat_err, lon_err

def decode(geohash):
    """
    Decode geohash, returning two strings with latitude and longitude
    containing only relevant digits and with trailing zeroes removed.
    """
    lat, lon, lat_err, lon_err = decode_exactly(geohash)
    # Format to the number of decimals that are known
    lats = "%.*f" % (max(1, int(round(-log10(lat_err)))) - 1, lat)
    lons = "%.*f" % (max(1, int(round(-log10(lon_err)))) - 1, lon)
    if '.' in lats: lats = lats.rstrip('0')
    if '.' in lons: lons = lons.rstrip('0')
    return lats, lons

def encode(latitude, longitude, precision=12):
    """
    Encode a position given in float arguments latitude, longitude to
    a geohash which will have the character count precision.
    """
    lat_interval, lon_interval = (-90.0, 90.0), (-180.0, 180.0)
    geohash = []
    bits = [ 16, 8, 4, 2, 1 ]
    bit = 0
    ch = 0
    even = True
    while len(geohash) < precision:
        if even:
            mid = (lon_interval[0] + lon_interval[1]) / 2
            if longitude > mid:
                ch |= bits[bit]
                lon_interval = (mid, lon_interval[1])
            else:
                lon_interval = (lon_interval[0], mid)
        else:
            mid = (lat_interval[0] + lat_interval[1]) / 2
            if latitude > mid:
                ch |= bits[bit]
                lat_interval = (mid, lat_interval[1])
            else:
                lat_interval = (lat_interval[0], mid)
        even = not even
        if bit < 4:
            bit += 1
        else:
            geohash += __base32[ch]
            bit = 0
            ch = 0
    return ''.join(geohash)

#############################################
############# END GEOHASH CODE ##############
#############################################

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

# lambda handler function
def process_stage_messages(message):

    print(f"=====================")
    print(f"---->\n Value of message: {message}")
    print(f"=====================")
    print(f"value of type(message): {type(message)}")

    # Get the SQS event message ID
    message_id   = message["messageId"]

    # Get the SQS event message body
    message_body = message["body"]

    print(f'---->\n Value of message_id: {message_id}')
    print(f'---->\n Value of message_body: {message_body}')
    print(f'---->\n Value of type(message_body): {type(message_body)}')

    print(f"Converting message_body to python dict via json.loads()...")

    # Try and convert the message_body string to a Python dictionary
    try:
        message_body = json.loads(message_body)
    except Exception as e:
        print(f"Error in json.loads() of message_body: {e}")
        raise

    print(f'---->\n Value of message_body: {message_body}')
    print(f'---->\n Value of type(message_body): {type(message_body)}')

    # #################################
    # # Example values from message_body (message_body is an S3 event message)
    # EVENT_TIME = "2019-09-03T19:37:27.192Z"
    # INPUT_S3_BUCKET = "test-staging-bucket-mros"
    # INPUT_OBJECT_KEY = "mros_staging_rec4pVBLnNgxeT1Nj_12_01_23.json"
    # #################################

    # # get the bucket name and object key from the event
    INPUT_S3_BUCKET  = message_body['Records'][0]['s3']['bucket']['name']
    INPUT_OBJECT_KEY = message_body['Records'][0]['s3']['object']['key']
    
    print(f"- INPUT_S3_BUCKET: {INPUT_S3_BUCKET}")
    print(f"- INPUT_OBJECT_KEY: {INPUT_OBJECT_KEY}")

    # try to get the eventTime from the message_body
    try:
        # get the eventTime from the message_body
        EVENT_TIME = message_body.get('Records', [])[0].get('eventTime')
        # EVENT_TIME       = message_body['Records'][0]['eventTime']
        if not EVENT_TIME:
            print(f"No eventTime found in message_body, defaulting to current time")

        # Use the current date and time as the default if EVENT_TIME is None
        EVENT_TIME = EVENT_TIME or datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.%fZ")

    except Exception as e:
        print(f"Error accessing 'eventTime' field: {e}")
        raise

    print(f"- EVENT_TIME: {EVENT_TIME}")

    # Parse the eventTime string into a datetime object
    parsed_event_time = datetime.strptime(EVENT_TIME, "%Y-%m-%dT%H:%M:%S.%fZ")

    # Extract month, day, and year
    month = parsed_event_time.strftime("%m")
    day   = parsed_event_time.strftime("%d")
    year  = parsed_event_time.year

    # create a date_key string
    date_key = f"{year}_{month}_{day}"

    print(f"data_key: {date_key}")
    print(f"Month: {month}, Day: {day}, Year: {year}")

    # # download the json input file from S3
    try:
        s3_obj = s3.get_object(Bucket=INPUT_S3_BUCKET, Key=INPUT_OBJECT_KEY)
    except Exception as e:
        print(f"Error retrieving S3 object: {e}")
        print(f"- Problem INPUT_S3_BUCKET: {INPUT_S3_BUCKET}")
        print(f"- Problem INPUT_OBJECT_KEY: {INPUT_OBJECT_KEY}")
        raise

    # get the contents of the file
    obj_content = json.load(s3_obj['Body'])

    # extract the JSON data from obj_content
    json_data = json.loads(obj_content[0])[0]

    print(f"Creating geohash from latitude and longitude...")
    print(f"- latitude: {json_data['latitude']}")
    print(f"- longitude: {json_data['longitude']}")

    # Create a geohash from the latitude and longitude with a precision of 5 characters (~ 4.9km x 4.9km)
    geohash5 = encode(float(json_data["latitude"]), float(json_data["longitude"]), 5)

    # Create a geohash from the latitude and longitude with a precision of 5 characters (~ 4.9km x 4.9km)
    geohash12 = encode(float(json_data["latitude"]), float(json_data["longitude"]), 12)

    print(f"Adding geohash5 '{geohash5}' to json_data...")
    print(f"Adding geohash12 '{geohash12}' to json_data...")

    # Add the geohash5 to the json_data
    json_data["geohash5"] = geohash5

    # Add the geohash12 to the json_data
    json_data["geohash12"] = geohash12

    # add the date_key to the json_data
    json_data["date_key"] = date_key
    
    # # Create a hash value for all of the data in the json_data dictionary
    # json_data["record_hash"] = hash_dictionary(json_data)
    
    # # use hash_pandas_object to generate a hash value for all the values in each row
    # df['record_hash'] = pd.util.hash_pandas_object(df, index=False)

    print(f"json_data: {json_data}")
    print(f"===" * 5)

    return json_data

# Give a dataframe with a "date_key" column, and split the dataframe into groups based on this columnd,
# then upload each of the grouped dataframes to S3
def upload_dataframes_by_date_key(df):
    # # Convert the list of JSON objects to a Pandas DataFrame
    # df = pd.DataFrame(json_list)

    # Group by the 'date_key' column
    grouped_df = df.groupby('date_key')

    # Create a dictionary of DataFrames for each group
    df_map = {date_key: group_df for date_key, group_df in grouped_df}
    print(f"Number of DataFrames in df_map: {len(df_map)}")
    print(f'Keys in df_map: {", ".join(list(df_map.keys()))}')

    # Iterate through the dictionary of DataFrames
    for date_key, group_df in df_map.items():
        print(f"Processing dataframes with date_key: '{date_key}'")

        # Extract year, month, and day from date_key
        DF_YEAR, DF_MONTH, DF_DAY = date_key.split("_")
        
        print(f"DF_YEAR: {DF_YEAR}\nDF_MONTH: {DF_MONTH}\nDF_DAY: {DF_DAY}")
        # print(f"DF_YEAR: {DF_YEAR}, DF_MONTH: {DF_MONTH}, DF_DAY: {DF_DAY}")
        print(f"Shape of '{date_key}' df: {group_df.shape}")
        print(f"Number ROWS in '{date_key}' df: {len(group_df)}")
        print(f"Number COLUMNS in '{date_key}' df: {len(group_df.columns)}")

        # Generate a unique CSV filename
        unique_id = f"{uuid.uuid4().hex}"
        print(f"Unique ID of CSV: '{unique_id}'")

        # Generate a timestamp to add to the OUTPUT_S3_OBJECT_NAME
        timestamp = int(time.time())
        print(f"Timestamp of CSV: {timestamp}")
        
        # Use uuid.uuid4() and current timestamp to create a unique filename
        csv_filename = f"{unique_id}_{timestamp}.csv"
        print(f"Unique CSV filename: '{csv_filename}'")

        # Create the S3 URI for the output CSV file
        S3_OUTPUT_OBJECT_KEY = f"s3://{S3_PROD_BUCKET}/{DF_YEAR}/{DF_MONTH}/{DF_DAY}/{csv_filename}"

        print(f"S3_OUTPUT_OBJECT_KEY: {S3_OUTPUT_OBJECT_KEY}")
        print(f"Saving dataframe to:\n - '{S3_OUTPUT_OBJECT_KEY}'")
        
        try:
            group_df.to_csv(S3_OUTPUT_OBJECT_KEY, index=False)
        except Exception as e:
            print(f"Error saving dataframe to S3: {e}")
            print(f"Problem S3_OUTPUT_OBJECT_KEY: {S3_OUTPUT_OBJECT_KEY}")
            print(f"Problem 'date_key': {date_key}")

        # # Save the DataFrame as CSV to S3
        # group_df.to_csv(S3_OUTPUT_OBJECT_KEY, index=False)

        print(f"===" * 5)

    return

# lambda handler function
def mros_stage_to_prod(event, context):

    print(f"=====================")
    print(f'---->\n Value of event: {event}')
    print(f"=====================")

    # S3_STAGE_BUCKET = "test-staging-bucket-mros"
    # S3_STAGE_BUCKET_URI = "s3://test-staging-bucket-mros"
    # S3_PROD_BUCKET = "tester-prod-bucket-mros"
    # S3_PROD_BUCKET_URI = "s3://tester-prod-bucket-mros"

    print(f"- S3_STAGE_BUCKET: {S3_STAGE_BUCKET}")
    print(f"- S3_PROD_BUCKET: {S3_PROD_BUCKET}")
    print(f"- S3_STAGE_BUCKET_URI: {S3_STAGE_BUCKET_URI}")
    print(f"- S3_PROD_BUCKET_URI: {S3_PROD_BUCKET_URI}")

    message_count = 0
    
    batch_item_failures = []
    sqs_batch_response = {}

    json_list = []

    for message in event['Records']:
    # for message in range(0, 3):

        message_count += 1
        # print(f"PROCESSING MESSAGE: {message_count}")
        print(f"PROCESSING MESSAGE: {message_count} / {len(event['Records'])}")
        try:
            stage_json = process_stage_messages(message)
            json_list.append(stage_json)
        except Exception as e:
            print(f"Exception raised from messageId {message['messageId']}\n: {e}")
            batch_item_failures.append({"itemIdentifier": message['messageId']})
        
    print(f"Number of JSONs in batch: {len(json_list)}")
    print(f"Converting batch of {len(json_list)} JSONs to Pandas DataFrame...")

    # Try to convert the list of JSON objects (dictionaries) to a Pandas DataFrame
    try:
        df = pd.DataFrame(json_list)
    except Exception as e:
        # if an error occurs, print the error and add all messages to batch_item_failures,
        # and then return sqs_batch_response
        print(f"---> ERROR converting JSON list to DataFrame: {e}")
        print(f"-----> Adding all messages to batch_item_failures to send back to SQS queue...")

        # loop through event['Records'] and add each message to batch_item_failures
        batch_item_failures = [{"itemIdentifier": message['messageId']} for message in event['Records']]
        sqs_batch_response["batchItemFailures"] = batch_item_failures

        print(f"Returning ALL messages to SQS queue early...")


        print(f"---> sqs_batch_response: {sqs_batch_response}")

        return sqs_batch_response

    print(f"Succesfully converted JSON list to DataFrame!")
    print(f"Uploading dataframe in groups by 'date_key' to S3...")
    
    print("Moving 'record_hash' column to the last position in the DataFrame...")
    
    # move the 'record_hash' column to the last position
    df.insert(len(df.columns)-1, 'record_hash', df.pop('record_hash'))

    # upload the dataframes to S3 by date_key column (year_month_day, e.g. 2021_01_01)
    upload_dataframes_by_date_key(df)

    sqs_batch_response["batchItemFailures"] = batch_item_failures
    print(f"sqs_batch_response: {sqs_batch_response}")

    return sqs_batch_response

# # lambda handler function
# def mros_stage_to_prod2(event, context):

#     print(f"=====================")
#     print(f'---->\n Value of event: {event}')
#     print(f"=====================")

#     S3_STAGE_BUCKET = "test-staging-bucket-mros"
#     S3_STAGE_BUCKET_URI = "s3://test-staging-bucket-mros"
#     S3_PROD_BUCKET = "tester-prod-bucket-mros"
#     S3_PROD_BUCKET_URI = "s3://tester-prod-bucket-mros"

#     print(f"- S3_STAGE_BUCKET: {S3_STAGE_BUCKET}")
#     print(f"- S3_PROD_BUCKET: {S3_PROD_BUCKET}")
#     print(f"- S3_STAGE_BUCKET_URI: {S3_STAGE_BUCKET_URI}")
#     print(f"- S3_PROD_BUCKET_URI: {S3_PROD_BUCKET_URI}")

#     message_count = 0
    
#     batch_item_failures = []
#     sqs_batch_response = {}

#     json_list = []

#     # for message in event['Records']:
#     for message in range(0, 3):

#         message_count += 1
#         print(f"PROCESSING MESSAGE: {message_count}")
#         # print(f"PROCESSING MESSAGE: {message_count} / {len(event['Records'])}")
#         try:
#             stage_json = process_stage_messages(message)
#             json_list.append(stage_json)
#         except Exception as e:
#             print(f"Exception raised from messageId {message['messageId']}\n: {e}")
#             batch_item_failures.append({"itemIdentifier": message['messageId']})
        
#     print(f"Number of JSONs in batch: {len(json_list)}")
    
#     print(f"Converting batch of {len(json_list)} JSONs to Pandas DataFrame...")

#     # convert the list of JSON objects (dictionaries) to a Pandas DataFrame
#     df = pd.DataFrame(json_list)

#     # Group by the 'Group' column
#     df = df.groupby('date_key')
#     # df_by_date = df.groupby('date_key')

#     # Create separate DataFrames for each group
#     df_map = {date_key: group_df for date_key, group_df in df}
#     # df_map = {date_key: group_df for date_key, group_df in df_by_date}
#     print(f"Number of DataFrames in df_map: {len(df_map)}")
#     print(f'Keys in df_map: {", ".join(list(df_map.keys()))}')

#     # Iterate through the dictionary of DataFrames
#     for date_key, group_df in df_map.items():

#         print(f"Processing dataframes with date_key: '{date_key}'")

#         # Extract the year, month, and day from the date_key
#         DF_YEAR, DF_MONTH, DF_DAY = date_key.split("_")

#         print(f"DF_YEAR: {DF_YEAR}\nDF_MONTH: {DF_MONTH}\nDF_DAY: {DF_DAY}")
#         # print(f"DF_YEAR: {DF_YEAR}, DF_MONTH: {DF_MONTH}, DF_DAY: {DF_DAY}")
#         print(f"Shape of '{date_key}' df: {group_df.shape}")
#         print(f"Number ROWS in '{date_key}' df: {len(group_df)}")
#         print(f"Number COLUMNS in '{date_key}' df: {len(group_df.columns)}")

#         # generate a random UUID to add to the OUTPUT_S3_OBJECT_NAME
#         unique_id = f"{uuid.uuid4().hex}"
#         print(f"Unique ID of CSV: '{unique_id}'")

#         # generate a timestamp to add to the OUTPUT_S3_OBJECT_NAME
#         timestamp = int(time.time())
#         print(f"Timestamp of CSV: {timestamp}")

#         # Use uuid.uuid4() and current timestamp to create a unique filename
#         csv_filename = f"{unique_id}_{timestamp}.csv"
#         print(f"Unique CSV filename: '{csv_filename}'")

#         # Create the S3 URI for the output CSV file
#         S3_OUTPUT_OBJECT_KEY = f"s3://{S3_PROD_BUCKET}/{DF_YEAR}/{DF_MONTH}/{DF_DAY}/{csv_filename}"
#         # S3_OUTPUT_OBJECT_KEY = f"{S3_PROD_BUCKET_URI}/{DF_YEAR}/{DF_MONTH}/{DF_DAY}/{csv_filename}"

#         print(f"S3_OUTPUT_OBJECT_KEY: {S3_OUTPUT_OBJECT_KEY}")
#         print(f"Saving dataframe to:\n - '{S3_OUTPUT_OBJECT_KEY}'")

#         # # save the dataframe as CSV to S3
#         group_df.to_csv(S3_OUTPUT_OBJECT_KEY, index=False)

#         print(f"=====================")
        
#     sqs_batch_response["batchItemFailures"] = batch_item_failures

#     print(f"sqs_batch_response: {sqs_batch_response}")

#     return sqs_batch_response

# # lambda handler function
# def mros_stage_to_prod(event, context):

#     # print(f"event: {event}")
#     print(f"- S3_BUCKET: {S3_BUCKET}")
#     print(f"- S3_STAGING_BUCKET: {S3_STAGING_BUCKET}")
#     print(f"- S3_PROD_BUCKET: {S3_PROD_BUCKET}")

#     # get a list of objects in the staging bucket
#     response = s3.list_objects(Bucket=S3_STAGING_BUCKET_NAME)

#     # get a list of JSON (".json") files in the staging bucket
#     json_files = [obj['Key'] for obj in response.get('Contents', []) if obj['Key'].lower().endswith('.json')]

#     json_list = []

#     # iterate through the list of JSON files
#     for json_file in json_files:
#         print(f"json_file: {json_file}")

#         # json_content = read_json_from_s3(bucket_name, json_file)

#         # get the object from S3
#         json_data = s3.get_object(Bucket=S3_STAGING_BUCKET_NAME, Key=json_file)

#         # get the contents of the file
#         obj_content = json.load(json_data['Body'])

#         json_list.append(json.loads(obj_content[0])[0])

#         print(f"==================")

#     # convert the list of JSON objects (dictionaries) to a Pandas DataFrame
#     df = pd.DataFrame(json_list)

#     # clean day date to use in the filename
#     clean_date = df.submitted_date.values[0].replace("/", "_")

#     # Save the dataframe to a parquet/CSV file in S3
#     s3_object = f"{S3_PROD_BUCKET}/daily/mros_observations_{clean_date}.csv"
#     # local_object = f"/Users/anguswatters/Desktop/mros_airtable_{clean_date}.csv"
#     # s3_object = f"{S3_BUCKET}/raw/mros_airtable_{clean_date}.parquet"

#     print(f"s3_object: {s3_object}")

#     print(f"Saving dataframe to {s3_object}")
#     print(f"df.shape: {df.shape}")

#     # # save the dataframe as a parquet to S3
#     df.to_csv(s3_object)

#     return