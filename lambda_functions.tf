##############################################################
# lambda_functions.tf — Serverless Lambda Handlers & Roles
##############################################################

# Execution Role for Lambda
resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.project_name}-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Name = "${var.project_name}-lambda-exec-role"
  }
}

# Attach Managed Policies
resource "aws_iam_role_policy_attachment" "lambda_basic_exec" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_xray" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# DynamoDB Access Policy for Lambda Functions
resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "${var.project_name}-lambda-dynamodb-policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.items_table.arn
      }
    ]
  })
}

# 1. GET Items Function
resource "aws_lambda_function" "get_items" {
  function_name    = "${var.project_name}-get-items"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  architectures    = ["arm64"]
  timeout          = 30
  memory_size      = 256
  filename         = "${path.module}/lambda_payload.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_payload.zip")

  environment {
    variables = {
      TABLE_NAME  = aws_dynamodb_table.items_table.name
      ENVIRONMENT = var.environment
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name = "${var.project_name}-get-items"
  }
}

# 2. POST (Create) Item Function
resource "aws_lambda_function" "create_item" {
  function_name    = "${var.project_name}-create-item"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 30
  memory_size      = 256
  filename         = "${path.module}/lambda_payload.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_payload.zip")

  environment {
    variables = {
      TABLE_NAME  = aws_dynamodb_table.items_table.name
      ENVIRONMENT = var.environment
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name = "${var.project_name}-create-item"
  }
}

# 3. DELETE Item Function
resource "aws_lambda_function" "delete_item" {
  function_name    = "${var.project_name}-delete-item"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  timeout          = 30
  memory_size      = 128
  filename         = "${path.module}/lambda_payload.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_payload.zip")

  environment {
    variables = {
      TABLE_NAME  = aws_dynamodb_table.items_table.name
      ENVIRONMENT = var.environment
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name = "${var.project_name}-delete-item"
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "get_items_logs" {
  name              = "/aws/lambda/${aws_lambda_function.get_items.function_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "create_item_logs" {
  name              = "/aws/lambda/${aws_lambda_function.create_item.function_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "delete_item_logs" {
  name              = "/aws/lambda/${aws_lambda_function.delete_item.function_name}"
  retention_in_days = 14
}

# Outputs
output "lambda_get_items_arn" {
  description = "ARN of the GET items Lambda function"
  value       = aws_lambda_function.get_items.arn
}

output "lambda_create_item_arn" {
  description = "ARN of the POST create item Lambda function"
  value       = aws_lambda_function.create_item.arn
}

output "lambda_delete_item_arn" {
  description = "ARN of the DELETE item Lambda function"
  value       = aws_lambda_function.delete_item.arn
}
