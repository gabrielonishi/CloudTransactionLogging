import json
import boto3
import os

s3 = boto3.client("s3")

def lambda_handler(event, context):
    bucket = os.environ["BUCKET_NAME"]
    client_id = event['pathParameters']['cid']
    
    try:
        response = s3.get_object(Bucket=bucket, Key=client_id)
        file_data = response["Body"].read().decode('utf-8')
        parsed_data = json.loads(file_data)
        
        return {
            'statusCode': 200,
            'body': parsed_data
        }
    except Exception as e:
        print(e)
        raise(e)
