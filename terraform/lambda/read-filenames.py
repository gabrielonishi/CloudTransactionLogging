import json
import boto3
import os

s3 = boto3.client("s3")

def list_files(bucket, prefix):
    response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)

    files = []

    for obj in response.get("Contents", []):
        file_path = obj["Key"]
        files.append(file_path)

    return files

def lambda_handler(event, context):
    bucket = os.environ["BUCKET_NAME"]
    prefix = ""  # Set the prefix if needed

    files = list_files(bucket, prefix)

    return {
        'statusCode': 200,
        'body': json.dumps(files)
    }
