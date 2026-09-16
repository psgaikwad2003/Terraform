# AWS Secrets Manager & Parameter Store Configuration
# Manages sensitive configuration values, database credentials, and API keys

# --- Secrets Manager ---

# Database Master Credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "prod/database/credentials"
  description             = "RDS master username and password"
  recovery_window_in_days = 7

  tags = {
    Name        = "db-credentials-secret"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "admin"
    password = "CHANGE_ME_BEFORE_APPLY" # Replace with a strong password or use random_password
    engine   = "mysql"
    host     = "localhost" # Will be updated after RDS is created
    port     = 3306
    dbname   = "appdb"
  })

  lifecycle {
    ignore_changes = [secret_string] # Prevent Terraform from overwriting manual rotations
  }
}

# API Keys Secret
resource "aws_secretsmanager_secret" "api_keys" {
  name                    = "prod/app/api-keys"
  description             = "Third-party API keys used by the application"
  recovery_window_in_days = 7

  tags = {
    Name        = "api-keys-secret"
    Environment = "production"
  }
}

resource "aws_secretsmanager_secret_version" "api_keys" {
  secret_id = aws_secretsmanager_secret.api_keys.id
  secret_string = jsonencode({
    stripe_key    = "sk_live_REPLACE_ME"
    sendgrid_key  = "SG.REPLACE_ME"
    google_maps   = "REPLACE_ME"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# JWT Signing Secret
resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "prod/app/jwt-secret"
  description             = "JWT signing secret for authentication tokens"
  recovery_window_in_days = 7

  tags = {
    Name        = "jwt-secret"
    Environment = "production"
  }
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = "REPLACE_WITH_A_STRONG_RANDOM_SECRET_256_BITS"

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Automatic Secret Rotation (example for DB credentials)
resource "aws_secretsmanager_secret_rotation" "db_rotation" {
  secret_id           = aws_secretsmanager_secret.db_credentials.id
  rotation_lambda_arn = aws_lambda_function.secrets_rotation.arn

  rotation_rules {
    automatically_after_days = 30
  }
}

# Placeholder for rotation Lambda (replace with actual rotation function)
resource "aws_lambda_function" "secrets_rotation" {
  function_name = "secrets-rotation-function"
  role          = aws_iam_role.secrets_rotation_role.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  filename      = "secrets_rotation.zip" # Provide the rotation Lambda zip

  environment {
    variables = {
      SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.us-east-1.amazonaws.com"
    }
  }

  tags = {
    Name = "secrets-rotation-lambda"
  }
}

resource "aws_iam_role" "secrets_rotation_role" {
  name = "secrets-rotation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "secrets_rotation_basic" {
  role       = aws_iam_role.secrets_rotation_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "secrets_rotation_policy" {
  name = "secrets-rotation-policy"
  role = aws_iam_role.secrets_rotation_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
        "secretsmanager:PutSecretValue",
        "secretsmanager:UpdateSecretVersionStage"
      ]
      Resource = "*"
    }]
  })
}

# --- SSM Parameter Store ---

# Application environment config (non-sensitive)
resource "aws_ssm_parameter" "app_env" {
  name  = "/prod/app/environment"
  type  = "String"
  value = "production"

  tags = {
    Environment = "production"
  }
}

resource "aws_ssm_parameter" "app_log_level" {
  name  = "/prod/app/log-level"
  type  = "String"
  value = "INFO"
}

resource "aws_ssm_parameter" "app_region" {
  name  = "/prod/app/region"
  type  = "String"
  value = "us-east-1"
}

# Database endpoint (populated after RDS creation)
resource "aws_ssm_parameter" "db_endpoint" {
  name  = "/prod/database/endpoint"
  type  = "String"
  value = "REPLACE_AFTER_RDS_CREATION"

  lifecycle {
    ignore_changes = [value]
  }
}

# Feature flags
resource "aws_ssm_parameter" "feature_dark_mode" {
  name  = "/prod/features/dark-mode"
  type  = "String"
  value = "true"
}

resource "aws_ssm_parameter" "feature_beta_signup" {
  name  = "/prod/features/beta-signup"
  type  = "String"
  value = "false"
}

# Outputs
output "db_secret_arn" {
  description = "ARN of the database credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
  sensitive   = true
}

output "api_keys_secret_arn" {
  description = "ARN of the API keys secret"
  value       = aws_secretsmanager_secret.api_keys.arn
  sensitive   = true
}
