resource "aws_lambda_function" "s3_manager_lambda" {
  function_name    = "s3_manager"
  filename         = "s3_manager.zip"
  source_code_hash = filebase64sha256("s3_manager.zip")
  handler          = "s3_manager.lambda_handler"
  role             = aws_iam_role.s3_manager_role.arn
  runtime          = "python3.9"

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.client-log-storage.id
    }
  }
}

resource "aws_cloudwatch_log_group" "read-file-lambda" {
  name              = "/aws/lambda/${aws_lambda_function.s3_manager_lambda.function_name}"
  retention_in_days = 30
}