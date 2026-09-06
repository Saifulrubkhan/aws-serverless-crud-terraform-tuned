resource "aws_api_gateway_rest_api" "crud" {
  name = "DynamoDBOperations"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "dynamodb_manager" {
  rest_api_id = aws_api_gateway_rest_api.crud.id
  parent_id   = aws_api_gateway_rest_api.crud.root_resource_id
  path_part   = "dynamodbmanager"
}

resource "aws_api_gateway_method" "post" {
  rest_api_id   = aws_api_gateway_rest_api.crud.id
  resource_id   = aws_api_gateway_resource.dynamodb_manager.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.crud.id
  resource_id             = aws_api_gateway_resource.dynamodb_manager.id
  http_method             = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.crud_function.invoke_arn
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.crud_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.crud.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "crud" {
  rest_api_id = aws_api_gateway_rest_api.crud.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_method.post,
      aws_api_gateway_integration.lambda,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_api_gateway_integration.lambda]
}

resource "aws_api_gateway_stage" "crud" {
  rest_api_id   = aws_api_gateway_rest_api.crud.id
  deployment_id = aws_api_gateway_deployment.crud.id
  stage_name    = var.api_stage_name
}
