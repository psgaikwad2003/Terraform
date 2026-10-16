##############################################################
# ssm_automation.tf — Systems Manager Parameters & Operations
##############################################################

# Application configuration stored in Parameter Store
resource "aws_ssm_parameter" "app_tier_config" {
  name        = "/${var.project_name}/${var.environment}/tier"
  description = "Runtime application tier identifier"
  type        = "String"
  value       = "web-api"

  tags = local.common_tags
}

resource "aws_ssm_parameter" "log_level" {
  name        = "/${var.project_name}/${var.environment}/log_level"
  description = "Application logging level"
  type        = "String"
  value       = "INFO"

  tags = local.common_tags
}

resource "aws_ssm_parameter" "db_endpoint" {
  name        = "/${var.project_name}/${var.environment}/db_endpoint"
  description = "Database connection endpoint"
  type        = "String"
  value       = aws_db_instance.primary.endpoint

  tags = local.common_tags
}

resource "aws_ssm_parameter" "redis_host" {
  name        = "/${var.project_name}/${var.environment}/redis_host"
  description = "Redis cache replication group host address"
  type        = "String"
  value       = aws_elasticache_replication_group.redis_cluster.primary_endpoint_address

  tags = local.common_tags
}

# Maintenance window for scheduled operating system patching
resource "aws_ssm_maintenance_window" "weekly_patching" {
  name     = "${var.project_name}-weekly-patch-window"
  schedule = "cron(0 2 ? * SUN *)" # Sunday 2:00 AM UTC
  duration = 3
  cutoff   = 1

  allow_unassociated_targets = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-patch-window"
  })
}

# SSM Automation document for fleet diagnostics and health checking
resource "aws_ssm_document" "fleet_health_check" {
  name          = "${var.project_name}-fleet-health-check"
  document_type = "Command"
  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Execute system diagnostics and memory validation across EC2 fleet"
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "CheckSystemHealth"
        inputs = {
          runCommand = [
            "echo 'Checking instance memory and disk usage...'",
            "free -m",
            "df -h",
            "uptime"
          ]
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-healthcheck-doc"
  })
}
