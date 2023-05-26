import json
import boto3
import os

s3 = boto3.client("s3")

def lambda_handler(event, context):
 
    # return {
    #     'statusCode': 200,
    #     'body': json.dumps(event)
    # }

    bucket = os.environ["BUCKET_NAME"]

    try:
        #Eventos GET
        if event["httpMethod"] == "GET":
            if event["path"] == "/filenames":
                files = get_filenames(bucket)
                return {
                    'statusCode': 200,
                    'body': json.dumps(files)
                }

    except Exception as e:
        raise(e)
    
def get_filenames(bucket):
    response = s3.list_objects_v2(Bucket=bucket, Prefix="")
    files = []
    for obj in response.get("Contents", []):
        file_path = obj["Key"]
        files.append(file_path)
    return files