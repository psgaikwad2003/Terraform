##############################################################
# kms_encryption.tf — Customer Managed Keys (CMK) & Policies
##############################################################

# KMS Key for General Storage & Object Encryption
resource "aws_kms_key" "storage_key" {
  description             = "Customer managed key for ${var.project_name} storage encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowS3AndCloudWatchAccess"
        Effect = "Allow"
        Principal = {
          Service = [
            "s3.amazonaws.com",
            "logs.${var.aws_region}.amazonaws.com"
          ]
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-storage-kms"
    Purpose = "Storage and Object Encryption"
  })
}

resource "aws_kms_alias" "storage_key_alias" {
  name          = "alias/${var.project_name}-storage"
  target_key_id = aws_kms_key.storage_key.key_id
}

# KMS Key for Database and Persistent Volumes
resource "aws_kms_key" "database_key" {
  description             = "Customer managed key for ${var.project_name} database and volume encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowRDSAndEBSAccess"
        Effect = "Allow"
        Principal = {
          Service = [
            "rds.amazonaws.com",
            "ec2.amazonaws.com"
          ]
        }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-database-kms"
    Purpose = "Database and Volume Encryption"
  })
}

resource "aws_kms_alias" "database_key_alias" {
  name          = "alias/${var.project_name}-database"
  target_key_id = aws_kms_key.database_key.key_id
}
