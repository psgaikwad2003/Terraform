# ─────────────────────────────────────────────
#  AWS DynamoDB Table
# ─────────────────────────────────────────────

resource "aws_dynamodb_table" "items_table" {
  name           = "items-table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  # Global Secondary Index for querying by status
  global_secondary_index {
    name               = "StatusIndex"
    hash_key           = "status"
    projection_type    = "ALL"
  }

  attribute {
    name = "status"
    type = "S"
  }

  # Enable Point-in-Time Recovery for data protection
  point_in_time_recovery {
    enabled = true
  }

  # Server-Side Encryption using AWS managed key
  server_side_encryption {
    enabled = true
  }

  # TTL attribute for automatic item expiry
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = {
    Name        = "items-table"
    Environment = "production"
  }
}

# ─────────────────────────────────────────────
#  DynamoDB Auto-Scaling (optional, for on-demand
#  you don't need this — kept here for reference)
# ─────────────────────────────────────────────

# DynamoDB Table for session/cache data
resource "aws_dynamodb_table" "sessions_table" {
  name           = "sessions-table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  # TTL for session expiry
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "sessions-table"
    Environment = "production"
  }
}

# ─────────────────────────────────────────────
#  CloudWatch Alarms for DynamoDB
# ─────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "dynamodb_throttled_requests" {
  alarm_name          = "dynamodb-throttled-requests"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "DynamoDB throttled requests exceeded threshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = aws_dynamodb_table.items_table.name
  }

  tags = {
    Name        = "dynamodb-throttled-requests-alarm"
    Environment = "production"
  }
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_system_errors" {
  alarm_name          = "dynamodb-system-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "SystemErrors"
  namespace           = "AWS/DynamoDB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "DynamoDB system errors detected"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = aws_dynamodb_table.items_table.name
  }

  tags = {
    Name        = "dynamodb-system-errors-alarm"
    Environment = "production"
  }
}

# ─────────────────────────────────────────────
#  Outputs
# ─────────────────────────────────────────────

output "dynamodb_items_table_name" {
  description = "Name of the DynamoDB items table"
  value       = aws_dynamodb_table.items_table.name
}

output "dynamodb_items_table_arn" {
  description = "ARN of the DynamoDB items table"
  value       = aws_dynamodb_table.items_table.arn
}

output "dynamodb_sessions_table_name" {
  description = "Name of the DynamoDB sessions table"
  value       = aws_dynamodb_table.sessions_table.name
}
