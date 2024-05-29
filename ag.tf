resource "aws_api_gateway_rest_api" "bus_interface" {
  name = "bus_interface"
}

resource "aws_api_gateway_resource" "message" {
  parent_id   = aws_api_gateway_rest_api.bus_interface.root_resource_id
  path_part   = "message"
  rest_api_id = aws_api_gateway_rest_api.bus_interface.id
}

resource "aws_api_gateway_method" "post_message" {
  authorization = "NONE"
  http_method   = "POST"
  resource_id   = aws_api_gateway_resource.message.id
  rest_api_id   = aws_api_gateway_rest_api.bus_interface.id
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = aws_api_gateway_rest_api.bus_interface.id
  resource_id             = aws_api_gateway_resource.message.id
  http_method             = aws_api_gateway_method.post_message.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.bus_producer.invoke_arn
}

resource "aws_api_gateway_deployment" "prod" {
  rest_api_id = aws_api_gateway_rest_api.bus_interface.id
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id        = aws_api_gateway_deployment.prod.id
  rest_api_id          = aws_api_gateway_rest_api.bus_interface.id
  stage_name           = "prod"
  xray_tracing_enabled = true
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bus_producer.function_name
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  source_arn = "${aws_api_gateway_rest_api.bus_interface.execution_arn}/*/*"
}