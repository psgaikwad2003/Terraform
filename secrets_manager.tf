##############################################################
# secrets_manager.tf — Secrets Manager & SSM Parameter Store
##############################################################

# 1. Application Database Master Credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}/database/credentials"
  description             = "Application database connection credentials"
  kms_key_id              = aws_kms_key.database_key.arn
  recovery_window_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-db-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "admin"
    password = "CHANGE_ME_BEFORE_APPLY"
    engine   = "postgres"
    host     = "localhost"
    port     = 5432
    dbname   = "appdb"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# 2. Third-Party API Keys Secret
resource "aws_secretsmanager_secret" "api_keys" {
  name                    = "${var.project_name}/app/api-keys"
  description             = "Third-party external service API keys"
  kms_key_id              = aws_kms_key.storage_key.arn
  recovery_window_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-api-keys"
  })
}

resource "aws_secretsmanager_secret_version" "api_keys" {
  secret_id = aws_secretsmanager_secret.api_keys.id
  secret_string = jsonencode({
    stripe_key   = "sk_live_PLACEHOLDER"
    sendgrid_key = "SG.PLACEHOLDER"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# 3. Application JWT Secret
resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "${var.project_name}/app/jwt-secret"
  description             = "JWT signing secret for authentication tokens"
  kms_key_id              = aws_kms_key.storage_key.arn
  recovery_window_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-jwt-secret"
  })
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = "DEFAULT_APPLICATION_JWT_SECRET_KEY_CHANGE_IN_PROD"

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# 4. SSM Parameter Store Configurations
resource "aws_ssm_parameter" "app_env" {
  name        = "/${var.project_name}/app/environment"
  description = "Application deployment environment name"
  type        = "String"
  tier        = "Standard"
  value       = var.environment

  tags = local.common_tags
}

resource "aws_ssm_parameter" "app_log_level" {
  name        = "/${var.project_name}/app/log-level"
  description = "Application logging verbosity level"
  type        = "String"
  tier        = "Standard"
  value       = "INFO"

  tags = local.common_tags
}

resource "aws_ssm_parameter" "app_region" {
  name        = "/${var.project_name}/app/region"
  description = "Application AWS deployment region"
  type        = "String"
  tier        = "Standard"
  value       = var.aws_region

  tags = local.common_tags
}

resource "aws_ssm_parameter" "feature_dark_mode" {
  name        = "/${var.project_name}/features/dark-mode"
  description = "Enable dark mode UI feature flag"
  type        = "String"
  tier        = "Standard"
  value       = "true"

  tags = local.common_tags
}

resource "aws_ssm_parameter" "feature_beta_signup" {
  name        = "/${var.project_name}/features/beta-signup"
  description = "Enable beta signup access feature flag"
  type        = "String"
  tier        = "Standard"
  value       = "false"

  tags = local.common_tags
}

resource "aws_ssm_parameter" "rate_limit_rpm" {
  name        = "/${var.project_name}/api/rate-limit-rpm"
  description = "Default per-client API rate limit in requests per minute"
  type        = "String"
  tier        = "Standard"
  value       = "1000"

  tags = local.common_tags
}

resource "aws_ssm_parameter" "feature_maintenance_mode" {
  name        = "/${var.project_name}/features/maintenance-mode"
  description = "Enable global maintenance mode kill-switch"
  type        = "String"
  tier        = "Standard"
  value       = "false"

  tags = local.common_tags
}

resource "aws_ssm_parameter" "api_cors_origins" {
  name        = "/${var.project_name}/api/cors-origins"
  description = "Allowed origins for API CORS preflight validation"
  type        = "String"
  tier        = "Standard"
  value       = "https://*.${var.project_name}.com"

  tags = local.common_tags
}


# Outputs
output "app_db_secret_arn" {
  description = "ARN of the application database credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
  sensitive   = true
}

output "api_keys_secret_arn" {
  description = "ARN of the API keys secret"
  value       = aws_secretsmanager_secret.api_keys.arn
}

output "jwt_secret_arn" {
  description = "ARN of the JWT signing secret"
  value       = aws_secretsmanager_secret.jwt_secret.arn
}

output "ssm_rate_limit_rpm_arn" {
  description = "ARN of the API rate limit SSM parameter"
  value       = aws_ssm_parameter.rate_limit_rpm.arn
}
