##############################################################
# eventbridge_events.tf — Event-Driven Architecture & Routing
##############################################################

# Custom EventBridge bus for enterprise domain events
resource "aws_cloudwatch_event_bus" "app_bus" {
  name = "${var.project_name}-event-bus"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-event-bus"
  })
}

# Event archive enabling point-in-time event replay for debugging and disaster recovery
resource "aws_cloudwatch_event_archive" "bus_archive" {
  name             = "${var.project_name}-bus-archive"
  event_source_arn = aws_cloudwatch_event_bus.app_bus.arn
  retention_days   = 30
  description      = "30-day event replay archive for ${var.project_name}"
}

# CloudWatch Log Group for auditing routed event patterns
resource "aws_cloudwatch_log_group" "eventbridge_logs" {
  name              = "/aws/events/${var.project_name}-audit"
  retention_in_days = 30

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eventbridge-logs"
  })
}

# Event rule matching application order and transactional events
resource "aws_cloudwatch_event_rule" "orders_rule" {
  name           = "${var.project_name}-orders-rule"
  description    = "Capture application transaction and order life-cycle events"
  event_bus_name = aws_cloudwatch_event_bus.app_bus.name

  event_pattern = jsonencode({
    source      = ["app.orders", "app.billing"]
    detail-type = ["OrderPlaced", "OrderCancelled", "PaymentReceived"]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-orders-rule"
  })
}

# Target 1: Forward matching events to SQS tasks queue
resource "aws_cloudwatch_event_target" "sqs_order_target" {
  rule           = aws_cloudwatch_event_rule.orders_rule.name
  event_bus_name = aws_cloudwatch_event_bus.app_bus.name
  target_id      = "SendToOrdersQueue"
  arn            = aws_sqs_queue.app_queue.arn

  dead_letter_config {
    arn = aws_sqs_queue.app_dlq.arn
  }
}

# Target 2: Audit matching events directly into CloudWatch Logs
resource "aws_cloudwatch_event_target" "cw_logs_target" {
  rule           = aws_cloudwatch_event_rule.orders_rule.name
  event_bus_name = aws_cloudwatch_event_bus.app_bus.name
  target_id      = "SendToCloudWatchAudit"
  arn            = aws_cloudwatch_log_group.eventbridge_logs.arn
}
