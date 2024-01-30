import os
from dotenv import load_dotenv

BASE_DIR = os.path.abspath(os.path.dirname(__name__))
load_dotenv(os.path.join(BASE_DIR, ".env"))

class Config:

    # General Config
    # DATE     = os.environ.get("DATE")
    BASE_ID  = os.environ.get("BASE_ID")
    TABLE_ID  = os.environ.get("TABLE_ID")
    AIRTABLE_TOKEN  = os.environ.get("AIRTABLE_TOKEN")
    
    S3_BUCKET  = os.environ.get("S3_BUCKET")
    S3_STAGING_BUCKET  = os.environ.get("S3_STAGING_BUCKET")
    S3_PROD_BUCKET  = os.environ.get("S3_PROD_BUCKET")

    SQS_QUEUE_URL  = os.environ.get("SQS_QUEUE_URL")