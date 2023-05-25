resource "aws_api_gateway_rest_api" "s3-management-api" {
  name               = "s3-management-api"
  binary_media_types = ["application/json"]
}

# resource "aws_api_gateway_resource" "upload" {
#   parent_id   = aws_api_gateway_rest_api.s3-management-api.root_resource_id
#   rest_api_id = aws_api_gateway_rest_api.s3-management-api.id
#   path_part   = "upload"
# }

resource "aws_api_gateway_resource" "cid" {
  parent_id   = aws_api_gateway_rest_api.s3-management-api.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.s3-management-api.id
  path_part   = "{cid}"
}

resource "aws_api_gateway_method" "get-filenames" {
  authorization = "NONE"
  http_method   = "GET"
  resource_id   = aws_api_gateway_rest_api.s3-management-api.root_resource_id
  rest_api_id   = aws_api_gateway_rest_api.s3-management-api.id
}

resource "aws_api_gateway_method" "get-file" {
  authorization = "NONE"
  http_method   = "GET"
  resource_id   = aws_api_gateway_resource.cid.id
  rest_api_id   = aws_api_gateway_rest_api.s3-management-api.id
}

resource "aws_api_gateway_integration" "read-filenames-lambda-integration" {
  rest_api_id = aws_api_gateway_rest_api.s3-management-api.id
  resource_id = aws_api_gateway_method.get-filenames.resource_id
  http_method = aws_api_gateway_method.get-filenames.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.read-filenames-lambda.invoke_arn
}

resource "aws_api_gateway_integration" "get-file-lambda-integration" {
  rest_api_id = aws_api_gateway_rest_api.s3-management-api.id
  resource_id = aws_api_gateway_method.get-file.resource_id
  http_method = aws_api_gateway_method.get-file.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.read-file-lambda.invoke_arn
}

resource "aws_lambda_permission" "read-filenames-lambda-permission" {
  statement_id  = "AllowS3ManagementAPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.read-filenames-lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.s3-management-api.execution_arn}/*"
}

resource "aws_lambda_permission" "read-file-lambda-permission" {
  statement_id  = "AllowS3ManagementAPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.read-file-lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.s3-management-api.execution_arn}/*"
}

resource "aws_api_gateway_deployment" "deploy-api" {
  rest_api_id = aws_api_gateway_rest_api.s3-management-api.id

  triggers = {
    redeployment = sha1(jsonencode([
      # aws_api_gateway_resource.example.id,
      aws_api_gateway_method.get-filenames.id,
      aws_api_gateway_integration.read-filenames-lambda-integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "dev-stage" {
  deployment_id = aws_api_gateway_deployment.deploy-api.id
  rest_api_id   = aws_api_gateway_rest_api.s3-management-api.id
  stage_name    = "dev"
}

output "api-url" {
  # value = aws_api_gateway_deployment.deploy-api.invoke_url
  value = aws_api_gateway_stage.dev-stage.invoke_url
}