# ─────────────────────────────────────────────
#  AWS Lambda Functions
# ─────────────────────────────────────────────

# IAM Role for Lambda execution
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "lambda-exec-role"
    Environment = "production"
  }
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_exec" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach DynamoDB access policy for Lambda
resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "lambda-dynamodb-access"
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
        Resource = "*"
      }
    ]
  })
}

# ─────────────────────────────────────────────
#  Lambda: GET Items Function
# ─────────────────────────────────────────────
resource "aws_lambda_function" "get_items" {
  function_name = "get-items-function"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 30
  memory_size   = 256

  filename         = "get_items.zip"
  source_code_hash = filebase64sha256("get_items.zip")

  environment {
    variables = {
      TABLE_NAME  = aws_dynamodb_table.items_table.name
      ENVIRONMENT = "production"
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name        = "get-items-function"
    Environment = "production"
  }
}

# ─────────────────────────────────────────────
#  Lambda: POST (Create) Item Function
# ─────────────────────────────────────────────
resource "aws_lambda_function" "create_item" {
  function_name = "create-item-function"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 30
  memory_size   = 256

  filename         = "create_item.zip"
  source_code_hash = filebase64sha256("create_item.zip")

  environment {
    variables = {
      TABLE_NAME  = aws_dynamodb_table.items_table.name
      ENVIRONMENT = "production"
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name        = "create-item-function"
    Environment = "production"
  }
}

# ─────────────────────────────────────────────
#  Lambda: DELETE Item Function
# ─────────────────────────────────────────────
resource "aws_lambda_function" "delete_item" {
  function_name = "delete-item-function"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 30
  memory_size   = 128

  filename         = "delete_item.zip"
  source_code_hash = filebase64sha256("delete_item.zip")

  environment {
    variables = {
      TABLE_NAME  = aws_dynamodb_table.items_table.name
      ENVIRONMENT = "production"
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name        = "delete-item-function"
    Environment = "production"
  }
}

# CloudWatch Log Groups for Lambda functions
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
