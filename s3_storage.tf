##############################################################
# FILE 3: s3_storage.tf — S3 Buckets for Company Storage
# Use-case: Create secure S3 buckets for app assets, logs,
#            and backups with versioning, lifecycle rules,
#            and server-side encryption. Daily ops staple.
##############################################################

# ─── Variables ───────────────────────────────────────────────
variable "log_retention_days"    { default = 90 }
variable "backup_retention_days" { default = 365 }

# ─── Random suffix to ensure globally unique names ───────────
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# ══════════════════════════════════════════════════════════════
# 1. Application Assets Bucket (public-readable static files)
# ══════════════════════════════════════════════════════════════
resource "aws_s3_bucket" "assets" {
  bucket        = "${var.project_name}-assets-${random_id.bucket_suffix.hex}"
  force_destroy = false
  tags          = { Purpose = "static-assets" }
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    id     = "transition-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["https://*.${var.project_name}.com"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# ══════════════════════════════════════════════════════════════
# 2. Access Logs Bucket (private, lifecycle auto-cleanup)
# ══════════════════════════════════════════════════════════════
resource "aws_s3_bucket" "logs" {
  bucket        = "${var.project_name}-logs-${random_id.bucket_suffix.hex}"
  force_destroy = false
  tags          = { Purpose = "access-logs" }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }

    expiration {
      days = var.log_retention_days
    }
  }
}

# ══════════════════════════════════════════════════════════════
# 3. Backup Bucket (with Object Lock for compliance)
# ══════════════════════════════════════════════════════════════
resource "aws_s3_bucket" "backups" {
  bucket              = "${var.project_name}-backups-${random_id.bucket_suffix.hex}"
  object_lock_enabled = true
  force_destroy       = false
  tags                = { Purpose = "backups", Compliance = "required" }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_object_lock_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = 30
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "archive-old-backups"
    status = "Enabled"

    transition {
      days          = 60
      storage_class = "GLACIER"
    }

    expiration {
      days = var.backup_retention_days
    }
  }
}

# ─── Bucket Policy: Enforce HTTPS only ───────────────────────
data "aws_iam_policy_document" "backups_policy" {
  statement {
    sid       = "DenyHTTP"
    effect    = "Deny"
    principals { type = "*" identifiers = ["*"] }
    actions   = ["s3:*"]
    resources = [
      aws_s3_bucket.backups.arn,
      "${aws_s3_bucket.backups.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "backups" {
  bucket = aws_s3_bucket.backups.id
  policy = data.aws_iam_policy_document.backups_policy.json
}

# ─── Outputs ──────────────────────────────────────────────────
output "assets_bucket_name"  { value = aws_s3_bucket.assets.id }
output "logs_bucket_name"    { value = aws_s3_bucket.logs.id }
output "backups_bucket_name" { value = aws_s3_bucket.backups.id }
output "assets_bucket_arn"   { value = aws_s3_bucket.assets.arn }
