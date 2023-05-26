resource "aws_api_gateway_rest_api" "client_log_management_API" {
  name               = "client_log_management_API"
  binary_media_types = ["application/json"]
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.client_log_management_API.id
  parent_id   = aws_api_gateway_rest_api.client_log_management_API.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.client_log_management_API.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = aws_api_gateway_rest_api.client_log_management_API.id
  resource_id = aws_api_gateway_method.proxy.resource_id
  http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.s3_manager_lambda.invoke_arn
}

resource "aws_api_gateway_method" "proxy_root" {
  rest_api_id   = aws_api_gateway_rest_api.client_log_management_API.id
  resource_id   = aws_api_gateway_rest_api.client_log_management_API.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id = aws_api_gateway_rest_api.client_log_management_API.id
  resource_id = aws_api_gateway_method.proxy_root.resource_id
  http_method = aws_api_gateway_method.proxy_root.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.s3_manager_lambda.invoke_arn
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_manager_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.client_log_management_API.execution_arn}/*/*"
}

resource "aws_api_gateway_usage_plan" "standard_usage_plan" {
  name = "standard_usage_plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.client_log_management_API.id
    stage  = aws_api_gateway_stage.dev-stage.stage_name
  }
}

resource "aws_api_gateway_api_key" "api_access_key" {
  name = "api_access_key"
}

resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.api_access_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.standard_usage_plan.id
}

resource "aws_api_gateway_deployment" "deploy-api" {
  rest_api_id = aws_api_gateway_rest_api.client_log_management_API.id

  triggers = {
    redeployment = sha1(jsonencode([
      # aws_api_gateway_resource.example.id,
      aws_api_gateway_method.proxy,
      aws_api_gateway_method.proxy_root,
      aws_api_gateway_integration.lambda,
      aws_api_gateway_integration.lambda_root,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "dev-stage" {
  deployment_id = aws_api_gateway_deployment.deploy-api.id
  rest_api_id   = aws_api_gateway_rest_api.client_log_management_API.id
  stage_name    = "dev"
}

output "api-url" {
  value = aws_api_gateway_stage.dev-stage.invoke_url
}

output "api-key" {
  value = aws_api_gateway_usage_plan_key.main.value
}
