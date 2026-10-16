##############################################################
# sqs_sns_messaging.tf — Asynchronous Messaging & Pub/Sub
##############################################################

# Dead-letter queue for failed standard messages
resource "aws_sqs_queue" "app_dlq" {
  name                      = "${var.project_name}-standard-dlq"
  message_retention_seconds = 1209600 # 14 days
  kms_master_key_id         = aws_kms_key.storage_key.arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-standard-dlq"
  })
}

# Primary standard queue for general background tasks
resource "aws_sqs_queue" "app_queue" {
  name                       = "${var.project_name}-tasks-queue"
  delay_seconds              = 0
  max_message_size           = 262144
  message_retention_seconds  = 345600 # 4 days
  receive_wait_time_seconds  = 20     # Long polling
  visibility_timeout_seconds = 60
  kms_master_key_id          = aws_kms_key.storage_key.arn

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.app_dlq.arn
    maxReceiveCount     = 5
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-tasks-queue"
  })
}

# Dead-letter queue for ordered FIFO processing
resource "aws_sqs_queue" "orders_fifo_dlq" {
  name                      = "${var.project_name}-orders-dlq.fifo"
  fifo_queue                = true
  message_retention_seconds = 1209600
  kms_master_key_id         = aws_kms_key.storage_key.arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-orders-dlq-fifo"
  })
}

# FIFO queue for ordered transaction handling
resource "aws_sqs_queue" "orders_fifo_queue" {
  name                        = "${var.project_name}-orders.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  kms_master_key_id           = aws_kms_key.storage_key.arn

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.orders_fifo_dlq.arn
    maxReceiveCount     = 3
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-orders-fifo"
  })
}

# SNS Topic for broadcasting event notifications
resource "aws_sns_topic" "notifications" {
  name              = "${var.project_name}-notifications-topic"
  kms_master_key_id = aws_kms_key.storage_key.arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sns-notifications"
  })
}

# Subscription bridging SNS notifications directly to standard SQS tasks
resource "aws_sns_topic_subscription" "queue_subscription" {
  topic_arn            = aws_sns_topic.notifications.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.app_queue.arn
  raw_message_delivery = true
}

# SQS Queue Policy granting SNS publishing permissions
resource "aws_sqs_queue_policy" "app_queue_policy" {
  queue_url = aws_sqs_queue.app_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSNSPublish"
        Effect    = "Allow"
        Principal = "*"
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.app_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.notifications.arn
          }
        }
      }
    ]
  })
}
