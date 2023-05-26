import json
import boto3
import os
import base64

s3 = boto3.client("s3")

def lambda_handler(event, context):

    bucket = os.environ["BUCKET_NAME"]
    
    try:
        #Eventos GET
        if event["httpMethod"] == "GET":
            if event["path"] == "/transactions":
                if event["queryStringParameters"] == None:
                    files = get_transactions(bucket)
                    return {
                        'statusCode': 200,
                        'body': json.dumps(files)
                    }
                else:
                    transaction_id = event["queryStringParameters"]["transactionId"]
                    filename = "transaction" + transaction_id + ".json"
                    status_code, body_response = get_file(bucket, filename)
                    return {
                            'statusCode': status_code,
                            'body': json.dumps(body_response)
                    }
            else:
                return {
                    'statusCode': 405,
                    'body': json.dumps("Endpoint inexistente")
                }
        elif event["httpMethod"] == "POST" and event["path"] == "/upload":
            status_code, message = post_file(bucket, event)
            return {
                'statusCode': status_code,
                'body': json.dumps(message)
            }
        else:
            return {
                'statusCode': 405,
                'body': json.dumps("Endpoint inexistente")
            }

    except Exception as e:
        return {
            'statusCode' : 500,
            'body': json.dumps(e)
        }
    
def get_transactions(bucket) -> list:
    response = s3.list_objects_v2(Bucket=bucket, Prefix="")
    files = []
    for obj in response.get("Contents", []):
        file_path = obj["Key"]
        files.append(file_path)
    return files

def get_file(bucket, filename):
    if filename not in get_transactions(bucket):
        return 404, "Transacao inexistente"

    response = s3.get_object(Bucket=bucket, Key=filename)
    file_data = response["Body"].read().decode('utf-8')
    parsed_json = json.loads(file_data)
    return 200, parsed_json

def post_file(bucket, event):

    file_data_base64 = event['body']
    file_data = base64.b64decode(file_data_base64).decode('utf-8')
    json_data = json.loads(file_data)
    filename = "transaction" + json_data["transactionId"] + ".json"
    if filename in get_transactions(bucket):
        return 409, "Arquivo com mesmo transactionId arquivado"
    upload_byte_stream = bytes(json.dumps(json_data).encode('utf-8'))
    s3.put_object(Bucket=bucket, Key=filename, Body=upload_byte_stream)
    return 200,  'Arquivo anexado com sucesso'
