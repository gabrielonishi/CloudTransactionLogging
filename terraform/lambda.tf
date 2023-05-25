# resource "aws_lambda_function" "read-filenames-lambda" {
#   function_name    = "read-filenames-lambda"
#   filename         = "read-filenames.zip"
#   source_code_hash = filebase64sha256("read-filenames.zip")
#   handler          = "read-filenames.lambda_handler"
#   role             = aws_iam_role.lambda-read-role.arn
#   runtime          = "python3.9"

#   environment {
#     variables = {
#       BUCKET_NAME = aws_s3_bucket.client-log-storage.id
#     }
#   }
# }

# resource "aws_cloudwatch_log_group" "read-filenames-lambda" {
#   name = "/aws/lambda/${aws_lambda_function.read-filenames-lambda.function_name}"
#   retention_in_days = 30
# }

# resource "aws_lambda_function" "read-file-lambda" {
#   function_name    = "read-file-lambda"
#   filename         = "read-files.zip"
#   source_code_hash = filebase64sha256("read-files.zip")
#   handler          = "read-files.lambda_handler"
#   role             = aws_iam_role.lambda-read-role.arn
#   runtime          = "python3.9"

#   environment {
#     variables = {
#       BUCKET_NAME = aws_s3_bucket.client-log-storage.id
#     }
#   }
# }

# resource "aws_cloudwatch_log_group" "read-file-lambda" {
#   name = "/aws/lambda/${aws_lambda_function.read-file-lambda.function_name}"
#   retention_in_days = 30
# }

# resource "aws_lambda_function" "write-file-lambda" {
#   function_name    = "write-file-lambda"
#   filename         = "upload-files.zip"
#   source_code_hash = filebase64sha256("upload-files.zip")
#   handler          = "upload-files.lambda_handler"
#   role             = aws_iam_role.lambda-write-role.arn
#   runtime          = "python3.9"

#   environment {
#     variables = {
#       BUCKET_NAME = aws_s3_bucket.client-log-storage.id
#     }
#   }
# }

# resource "aws_cloudwatch_log_group" "write-file-lambda" {
#   name = "/aws/lambda/${aws_lambda_function.write-file-lambda.function_name}"
#   retention_in_days = 30
# }

resource "aws_lambda_function" "read-file-lambda" {
  function_name    = "read-file-lambda"
  filename         = "read-files.zip"
  source_code_hash = filebase64sha256("read-files.zip")
  handler          = "read-files.lambda_handler"
  role             = aws_iam_role.lambda-read-role.arn
  runtime          = "python3.9"

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.client-log-storage.id
    }
  }
}

resource "aws_cloudwatch_log_group" "read-file-lambda" {
  name = "/aws/lambda/${aws_lambda_function.read-file-lambda.function_name}"
  retention_in_days = 30
}