# ─────────────────────────────────────────────
#  AWS API Gateway (REST API)
# ─────────────────────────────────────────────

# REST API
resource "aws_api_gateway_rest_api" "main_api" {
  name        = "main-rest-api"
  description = "Main REST API for the serverless application"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = "main-rest-api"
    Environment = "production"
  }
}

# ─────────────────────────────────────────────
#  Resource: /items
# ─────────────────────────────────────────────
resource "aws_api_gateway_resource" "items_resource" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  parent_id   = aws_api_gateway_rest_api.main_api.root_resource_id
  path_part   = "items"
}

# ─────────────────────────────────────────────
#  GET /items  → get_items Lambda
# ─────────────────────────────────────────────
resource "aws_api_gateway_method" "get_items_method" {
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  resource_id   = aws_api_gateway_resource.items_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_items_integration" {
  rest_api_id             = aws_api_gateway_rest_api.main_api.id
  resource_id             = aws_api_gateway_resource.items_resource.id
  http_method             = aws_api_gateway_method.get_items_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_items.invoke_arn
}

resource "aws_lambda_permission" "api_gw_get_items" {
  statement_id  = "AllowAPIGatewayInvokeGetItems"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_items.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main_api.execution_arn}/*/*"
}

# ─────────────────────────────────────────────
#  POST /items  → create_item Lambda
# ─────────────────────────────────────────────
resource "aws_api_gateway_method" "post_items_method" {
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  resource_id   = aws_api_gateway_resource.items_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post_items_integration" {
  rest_api_id             = aws_api_gateway_rest_api.main_api.id
  resource_id             = aws_api_gateway_resource.items_resource.id
  http_method             = aws_api_gateway_method.post_items_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.create_item.invoke_arn
}

resource "aws_lambda_permission" "api_gw_create_item" {
  statement_id  = "AllowAPIGatewayInvokeCreateItem"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_item.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main_api.execution_arn}/*/*"
}

# ─────────────────────────────────────────────
#  Resource: /items/{id}
# ─────────────────────────────────────────────
resource "aws_api_gateway_resource" "item_id_resource" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  parent_id   = aws_api_gateway_resource.items_resource.id
  path_part   = "{id}"
}

# DELETE /items/{id}  → delete_item Lambda
resource "aws_api_gateway_method" "delete_item_method" {
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  resource_id   = aws_api_gateway_resource.item_id_resource.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "delete_item_integration" {
  rest_api_id             = aws_api_gateway_rest_api.main_api.id
  resource_id             = aws_api_gateway_resource.item_id_resource.id
  http_method             = aws_api_gateway_method.delete_item_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.delete_item.invoke_arn
}

resource "aws_lambda_permission" "api_gw_delete_item" {
  statement_id  = "AllowAPIGatewayInvokeDeleteItem"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_item.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main_api.execution_arn}/*/*"
}

# ─────────────────────────────────────────────
#  API Deployment & Stage
# ─────────────────────────────────────────────
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.items_resource.id,
      aws_api_gateway_method.get_items_method.id,
      aws_api_gateway_method.post_items_method.id,
      aws_api_gateway_method.delete_item_method.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  stage_name    = "prod"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw_logs.arn
  }

  xray_tracing_enabled = true

  tags = {
    Name        = "prod-stage"
    Environment = "production"
  }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gw_logs" {
  name              = "/aws/api-gateway/${aws_api_gateway_rest_api.main_api.name}"
  retention_in_days = 14
}

# ─────────────────────────────────────────────
#  Outputs
# ─────────────────────────────────────────────
output "api_gateway_url" {
  description = "Base URL of the deployed API Gateway"
  value       = "${aws_api_gateway_stage.prod_stage.invoke_url}/items"
}
