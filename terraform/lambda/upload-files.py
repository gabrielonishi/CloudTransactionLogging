import boto3
import json
import base64
import os

s3 = boto3.client("s3")

def lambda_handler(event, context):
    
    # return {
    #     'statusCode': 200,
    #     'body': event["body-json"]
    # }
    
    bucket = os.environ["BUCKET_NAME"]
        
    try:
        # Retrieve the base64-encoded file data from the request body
        file_data_base64 = event['body-json']
        
        # Decode the base64 data
        file_data = base64.b64decode(file_data_base64).decode('utf-8')
        
        # Check if the content type is JSON
        content_type = event['params']['header']['Content-Type']
        if content_type != 'application/json':
            return {
                'statusCode': 400,
                'body': json.dumps('Invalid content type. Expected application/json.')
            }
        
        # Parse the JSON data
        try:
            json_data = json.loads(file_data)
        except json.JSONDecodeError:
            return {
                'statusCode': 400,
                'body': json.dumps('Invalid JSON data.')
            }
        
        # Generate a unique key for the S3 object (you can modify this as per your requirements)
        key = "CID-" + json_data["customerId"] + ".json"
        
        # Upload the JSON file to S3 bucket
        s3.put_object(Bucket=bucket, Key=key, Body=json.dumps(json_data))
        
        return {
            'statusCode': 200,
            'body': json.dumps('File uploaded successfully')
        }
        
    except Exception as e:
        print(e)
        raise(e)
