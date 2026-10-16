##############################################################
# glue_athena_analytics.tf — Data Lake & Analytics Engine
##############################################################

# S3 Bucket for raw data lake, partitions, and Athena query output
resource "aws_s3_bucket" "data_lake" {
  bucket        = "${var.project_name}-analytics-datalake-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-datalake"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "datalake_encryption" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "datalake_public_block" {
  bucket                  = aws_s3_bucket.data_lake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# AWS Glue Catalog Database
resource "aws_glue_catalog_database" "analytics_db" {
  name        = "${replace(var.project_name, "-", "_")}_analytics_db"
  description = "Central data catalog database for application analytics"
}

# IAM Role for AWS Glue Crawler
resource "aws_iam_role" "glue_crawler_role" {
  name = "${var.project_name}-glue-crawler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "glue_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
  role       = aws_iam_role.glue_crawler_role.name
}

resource "aws_iam_role_policy" "glue_s3_access" {
  name = "${var.project_name}-glue-s3-policy"
  role = aws_iam_role.glue_crawler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.data_lake.arn,
          "${aws_s3_bucket.data_lake.arn}/*"
        ]
      }
    ]
  })
}

# AWS Glue Crawler discovering parquet and JSON data schemas
resource "aws_glue_crawler" "data_crawler" {
  database_name = aws_glue_catalog_database.analytics_db.name
  name          = "${var.project_name}-datalake-crawler"
  role          = aws_iam_role.glue_crawler_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.data_lake.bucket}/raw-data/"
  }

  schedule = "cron(0 1 * * ? *)" # 1 AM daily

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-glue-crawler"
  })
}

# AWS Athena Workgroup for interactive SQL analysis with cost control limits
resource "aws_athena_workgroup" "analytics_workgroup" {
  name        = "${var.project_name}-athena-workgroup"
  description = "Workgroup enforcing encryption and query cost controls"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    bytes_scanned_cutoff_per_query     = 10737418240 # 10 GB safeguard limit

    result_configuration {
      output_location = "s3://${aws_s3_bucket.data_lake.bucket}/athena-results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-athena-workgroup"
  })
}
