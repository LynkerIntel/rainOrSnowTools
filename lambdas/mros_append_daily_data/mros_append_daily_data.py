# Description: Lambda function runs when new messages appear in SQS queue and takes the S3 event notification info from the message,
#  downloads the new input dataset, and appends it to the existing stationary CSV file in S3.
# Usage: python mros_airtable_to_sqs.py
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

# session = boto3.Session(profile_name='angus-lynker')
# s3 = session.client('s3')

# S3 client
s3 = boto3.client('s3')
    
# lambda handler function
def mros_append_daily_data(event, context):
    print(f"===" * 5)
    print(f"event: {event}")
    print(f"===" * 5)
    
    # Get the SQS event message
    message = event['Records'][0]

    print(f"message: {message}")
    
    # print(f"Converting message from JSON to dict...")
    
    # # Convert the SQS event message from JSON to dict
    # message = json.loads(message)
    
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
    # INPUT_S3_BUCKET = message_body['s3']['bucket']['name']
    # INPUT_OBJECT_KEY = message_body['s3']['object']['key']

    # # get the bucket name and object key from the event
    # INPUT_S3_BUCKET = event['Records'][0]["body"]['s3']['bucket']['name']
    # INPUT_OBJECT_KEY = event['Records'][0]["body"]['s3']['object']['key']

    print(f"- INPUT_S3_BUCKET: {INPUT_S3_BUCKET}")
    print(f"- INPUT_OBJECT_KEY: {INPUT_OBJECT_KEY}")
    print(f"- OUTPUT_S3_BUCKET: {OUTPUT_S3_BUCKET}")
    print(f"- OUTPUT_OBJECT_KEY: {OUTPUT_OBJECT_KEY}")

    # Get the filename from the INPUT object key
    INPUT_OBJ_FILENAME = os.path.basename(INPUT_OBJECT_KEY)
    OUTPUT_OBJ_FILENAME = os.path.basename(INPUT_OBJECT_KEY)

    print(f"- INPUT_OBJ_FILENAME: {INPUT_OBJ_FILENAME}")
    print(f"- OUTPUT_OBJ_FILENAME: {OUTPUT_OBJ_FILENAME}")

    # Create the local file path to save the S3 object to
    local_input_filepath  = f"/tmp/{INPUT_OBJ_FILENAME}"
    local_output_filepath = f"/tmp/{OUTPUT_OBJECT_KEY}"

    # print(f"event: {event}")
    print(f"- local_input_filepath: {local_input_filepath}")
    print(f"- local_output_filepath: {local_output_filepath}")

    # download the INPUT file from S3
    try:
        s3.download_file(INPUT_S3_BUCKET, INPUT_OBJECT_KEY, local_input_filepath)
    except Exception as e:
        print(f"Exception downloading INPUT file from S3: {e}")
        print(f"- Problem INPUT_OBJECT_KEY: {INPUT_OBJECT_KEY}")
        print(f"- Problem INPUT_OBJ_FILENAME: {INPUT_OBJ_FILENAME}")
        print(f"- Problem local_input_filepath: {local_input_filepath}")

    # download the OUTPUT file from S3
    try:
        s3.download_file(OUTPUT_S3_BUCKET, OUTPUT_OBJECT_KEY, local_output_filepath)
    except Exception as e:
        print(f"Exception downloading OUTPUT file from S3: {e}")
        print(f"- Problem OUTPUT_OBJECT_KEY: {OUTPUT_OBJECT_KEY}")
        print(f"- Problem OUTPUT_OBJ_FILENAME: {OUTPUT_OBJ_FILENAME}")
        print(f"- Problem local_output_filepath: {local_output_filepath}")

    print(f"Reading INPUT file into dataframe...")    

    # read the NEW input file into a pandas dataframe
    input_df  = pd.read_csv(local_input_filepath)
    
    print(f"Reading OUTPUT file into dataframe...")    

    # read the STATIONARY, OLD output file into a pandas dataframe
    output_df = pd.read_csv(local_output_filepath)

    # output_df = pd.read_csv(f'/tmp/{OUTPUT_OBJECT_KEY}')
    # input_df  = pd.read_csv(f'/tmp/{INPUT_OBJECT_KEY}')

    # Print out INPUT dataframe dimensions
    print(f"- input_df.shape: {input_df.shape}")
    print(f"- Number of columns in input_df: {len(input_df.columns)}")
    print(f"- Number of rows in input_df: {len(input_df)}")

    # Print out OUTPUT dataframe dimensions
    print(f"- output_df.shape: {output_df.shape}")
    print(f"- Number of columns in output_df: {len(output_df.columns)}")
    print(f"- Number of rows in output_df: {len(output_df)}")
    
    ####################################################
    #### OLD METHOD OF REMOVING DUPLICATES (BELOW) ####
    # # Create a new column 'duplicate_count_id' which is the concatenation of 'duplicate_id' and 'duplicate_count' in both dataframes
    # # This will be used to remove rows in the input dataframe that are already in the output dataframe
    # input_df["duplicate_count_id"] = input_df["duplicate_id"] + "_" + input_df["duplicate_count"].astype(str)
    # output_df["duplicate_count_id"] = output_df["duplicate_id"] + "_" + output_df["duplicate_count"].astype(str)

    # print(f"Number of rows in input_df: {len(input_df)} (BEFORE removing duplicates)")
    
    # # Remove rows of the "input_df" that have a "duplicate_count_id" that is already in the "output_df"
    # # This is to prevent duplicate rows from being added to the output file
    # input_df = input_df[-input_df["duplicate_count_id"].isin(output_df["duplicate_count_id"])]

    # print(f"Number of rows in input_df: {len(input_df)} (AFTER removing duplicates)")
    
    # print(f"Dropping 'duplicate_count_id' column from input_df and output_df...")

    # # Drop the 'duplicate_count_id' column from both dataframes
    # input_df.drop(columns=["duplicate_count_id"], inplace=True)
    # output_df.drop(columns=["duplicate_count_id"], inplace=True)

    #### OLD METHOD OF REMOVING DUPLICATES (ABOVE) ####
    ####################################################

    print(f"Number of rows in input_df: {len(input_df)} (BEFORE removing duplicate record_hash values)")

    # Remove rows of the "input_df" that have a "duplicate_count_id" that is already in the "output_df"
    # This is to prevent duplicate rows from being added to the output file
    input_df = input_df[-input_df["record_hash"].isin(output_df["record_hash"])]

    print(f"Number of rows in input_df: {len(input_df)} (AFTER removing duplicate record_hash values)")

    print(f"Concatenating dataframes...")

    # Concatenate the input file to the output file
    output_df = pd.concat([output_df, input_df], axis=0)

    print(f"FINAL OUTPUT dataframe dimensions:")
    print(f"- output_df.shape: {output_df.shape}")
    print(f"- Number of columns in output_df: {len(output_df.columns)}")
    print(f"- Number of rows in output_df: {len(output_df)}")

    # Create the S3 URI for the output CSV file
    UPDATED_S3_OBJECT_KEY = f"s3://{OUTPUT_S3_BUCKET}/{OUTPUT_OBJECT_KEY}"

    print(f"UPDATED_S3_OBJECT_KEY: {UPDATED_S3_OBJECT_KEY}")
    print(f"Saving dataframe to {UPDATED_S3_OBJECT_KEY}")
    print(f"FINAL output_df.shape: {output_df.shape}")
    print(f"FINAL len(output_df): {len(output_df)}")
    # output_df.to_csv(f'/tmp/{OUTPUT_OBJECT_KEY}', index=False)
    
    try:
        # # save the dataframe as a parquet to S3
        output_df.to_csv(UPDATED_S3_OBJECT_KEY, index=False)
    except Exception as e:
        print(f"Exception saving dataframe to S3: {e}")
        print(f"- Problem INPUT_OBJECT_KEY: {INPUT_OBJECT_KEY}")
        print(f"- Problem UPDATED_S3_OBJECT_KEY: {UPDATED_S3_OBJECT_KEY}")
        print(f"-----> RAISING EXCEPTION ON UPLOAD TO S3 <-----")
        raise

    print(f"====" * 6)
    # # append the input file to the output file
    # with open('/tmp/input.csv', 'r') as f:
    #     with open(f'/tmp/{OUTPUT_OBJECT_KEY}', 'a') as f1:
    #         for line in f:
    #             f1.write(line)

    return

# message = {'messageId': 'efaec386-afa0-438f-ac64-742ebc9230b9',
#   'receiptHandle': 'AQEBAAPlc2hSJLEuj5JIwH0tkeoWxa5a2pU+9EN4cr2m80MlgjZFdQzUSGBXHuc2OMPdxI4JoWdINzW6N6baEA0u68jbTvNgUBa4D/8UTdMxeNnbUkX4PmR10RaO/MpMEuksgT+1PTycZUHYrkg0RxXvlnQhnMEEvw0ClXVBrklAPfx2XrvM32LcSlYkvTc/3wkUIn4bUXlTFMVfcYxpvustzo+wc8o8loHZ2cKbG1NlnfBeS5brP0u202Bc8hb5m8HBhMrygji8atnpT2ClATkCGZ3oI+GJoqoSs+Ufk7pNYERgOnNXLOQGIwlSJujB5alzaFaC7Ee0wnuCn9oXbaj1ydd+VeL4TRHunDosuOe633uNzqcaT6bll467qhnSwyBJVsTX6gfXBi9pl2hLdd7YrheBClv2Oczi4gKwrz5Q8cQ=', 'body': '{\n "Type" : "Notification",\n "MessageId" : "9eab2542-ac5a-526f-a061-7b6b6ea6767f",\n "TopicArn" : "arn:aws:sns:us-west-1:645515465214:mros-output-data-sns-topic",\n "Subject" : "Amazon S3 Notification",\n "Message" : "{\\"Records\\":[{\\"eventVersion\\":\\"2.1\\",\\"eventSource\\":\\"aws:s3\\",\\"awsRegion\\":\\"us-west-1\\",\\"eventTime\\":\\"2024-01-23T13:35:55.842Z\\",\\"eventName\\":\\"ObjectCreated:Put\\",\\"userIdentity\\":{\\"principalId\\":\\"AWS:AROAZMS5YKH7GKY6KH7TW:mros-staging-processor\\"},\\"requestParameters\\":{\\"sourceIPAddress\\":\\"13.57.220.166\\"},\\"responseElements\\":{\\"x-amz-request-id\\":\\"KZQ5G47ZTVHWW9S2\\",\\"x-amz-id-2\\":\\"Pneh5CJ+IFfehfzN0EQP0boii/hKr+iU84IJ5WiwXsCjkXOIj3WCbSI5tfyAiCfHTY4CDk+cla9nIDptxBmIv0FWTJwIWaaf\\"},\\"s3\\":{\\"s3SchemaVersion\\":\\"1.0\\",\\"configurationId\\":\\"tf-s3-topic-20240123130120246900000001\\",\\"bucket\\":{\\"name\\":\\"mros-prod-bucket\\",\\"ownerIdentity\\":{\\"principalId\\":\\"A1FSC2N635XIDV\\"},\\"arn\\":\\"arn:aws:s3:::mros-prod-bucket\\"},\\"object\\":{\\"key\\":\\"2024/01/23/3c616722cf974348bb71c77548c77d67_1706016953.csv\\",\\"size\\":3007,\\"eTag\\":\\"1bfa9f33f3502c81b5930a8f34ebc57e\\",\\"sequencer\\":\\"0065AFC0BBC238D949\\"}}}]}",\n "Timestamp" : "2024-01-23T13:35:56.729Z",\n "SignatureVersion" : "1",\n "Signature" : "MFNFm0j5C4fp19uKL2gXvCdRHHBA1Rs26GST2X5wlls8SjcT6PLMHq76kb28XbU9V0Mu+7G0ZvqXkmxF3IrDS0zN1sjnhn/bP3aFTP2AfEPiqCH4FXqgwSsCmwTckDpNsyTLkUEZlAPQeR0ZzyDYTxjd89cRL3JexUsQHt4zUiiT+L0X4n+6E7Kb/diCsaEATRSAIaXkhH7nbCRprvvqlTkVNs0k0vz9YQ4r8y8tHBvg+xfPMMQhOLJIH7EuLQRBPL/hbiZKcJehnfOURnhiFQW/GUjYquim05NRyyFvfLES3G/km00O+bMWRpVIdclIT+R+kbZeEXESMFFYn/Hxgw==",\n "SigningCertURL" : "https://sns.us-west-1.amazonaws.com/SimpleNotificationService-60eadc530605d63b8e62a523676ef735.pem",\n "UnsubscribeURL" : "https://sns.us-west-1.amazonaws.com/?Action=Unsubscribe&SubscriptionArn=arn:aws:sns:us-west-1:645515465214:mros-output-data-sns-topic:f837e23b-6944-4113-828c-e3911a14d4bc"\n}', 
#   'attributes': {'ApproximateReceiveCount': '1', 'AWSTraceHeader': 'Root=1-65afc0b5-3b020c773954f69e99845df2;Parent=6129f264074925fd;Sampled=0', 'SentTimestamp': '1706016956754', 'SenderId': 'AIDAJKV7U6VPUEF2G77MA', 
#   'ApproximateFirstReceiveTimestamp': '1706016986754'}, 'messageAttributes': {}, 'md5OfMessageAttributes': None, 'md5OfBody': '09a3d249f1cea978ae5cfefdf71eb9cd', 
#   'eventSource': 'aws:sqs', 'eventSourceARN': 'arn:aws:sqs:us-west-1:645515465214:mros-prod-to-output-queue', 'awsRegion': 'us-west-1'}
# message_body = message["body"]
# json.loads(message_body)
