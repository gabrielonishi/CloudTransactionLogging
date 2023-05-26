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
            elif event["path"] == "/fetch-file":
                client_file = get_file(bucket, event)
                if client_file is not None:
                    return {
                        'statusCode': 200,
                        'body': json.loads(client_file)
                    }
                return {
                    'statusCode': 404,
                    'body': json.dumps("Cliente não possui logs")
                }
            else:
                return {
                    'statusCode': 405,
                    'body': json.dumps("Endpoint não aplicada")
                }
    except Exception as e:
        raise(e)
    
def get_filenames(bucket) -> list:
    response = s3.list_objects_v2(Bucket=bucket, Prefix="")
    files = []
    for obj in response.get("Contents", []):
        file_path = obj["Key"]
        files.append(file_path)
    return files

def get_file(bucket, event):
    client_id = event["queryStringParameters"]["client_id"]
    filename = "CID-" + client_id + ".json"
    if filename in get_filenames(bucket):
        response = s3.get_object(Bucket=bucket, Key=filename)
        file_data = response["Body"].read().decode('utf-8')
        return file_data
    return None