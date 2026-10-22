##############################################################
# kinesis_streaming.tf — Real-Time Event Streaming & Ingestion
##############################################################

# Scalable Kinesis Data Stream with KMS encryption for real-time ingestion
resource "aws_kinesis_stream" "events_stream" {
  name             = "${local.name_prefix}-events-stream"
  shard_count      = var.kinesis_shard_count
  retention_period = var.kinesis_retention_period_hours

  shard_level_metrics = [
    "IncomingBytes",
    "IncomingRecords",
    "OutgoingBytes",
    "OutgoingRecords",
    "ReadProvisionedThroughputExceeded",
    "WriteProvisionedThroughputExceeded"
  ]

  encryption_type = "KMS"
  kms_key_id      = aws_kms_key.storage_key.arn

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-events-stream"
  })
}

# CloudWatch Log Group for Firehose delivery stream errors and monitoring
resource "aws_cloudwatch_log_group" "firehose_logs" {
  name              = "/aws/kinesisfirehose/${local.name_prefix}-s3-delivery"
  retention_in_days = 30

  tags = local.common_tags
}

resource "aws_cloudwatch_log_stream" "firehose_log_stream" {
  name           = "S3Delivery"
  log_group_name = aws_cloudwatch_log_group.firehose_logs.name
}

# Dedicated IAM role for Kinesis Data Firehose
resource "aws_iam_role" "firehose_role" {
  name = "${local.name_prefix}-firehose-delivery-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

# IAM policy granting Firehose rights to read from Kinesis, write to S3, and log to CloudWatch
resource "aws_iam_role_policy" "firehose_policy" {
  name = "${local.name_prefix}-firehose-delivery-policy"
  role = aws_iam_role.firehose_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards"
        ]
        Resource = aws_kinesis_stream.events_stream.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.data_lake.arn,
          "${aws_s3_bucket.data_lake.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.storage_key.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.firehose_logs.arn}:*"
      }
    ]
  })
}

# Kinesis Firehose Delivery Stream delivering buffered events to Data Lake S3
resource "aws_kinesis_firehose_delivery_stream" "events_delivery" {
  name        = "${local.name_prefix}-events-delivery"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.events_stream.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose_role.arn
    bucket_arn          = aws_s3_bucket.data_lake.arn
    prefix              = "kinesis-events/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "kinesis-errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/"
    buffering_size      = 5
    buffering_interval  = 300
    compression_format  = "GZIP"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose_logs.name
      log_stream_name = aws_cloudwatch_log_stream.firehose_log_stream.name
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-events-delivery"
  })
}
