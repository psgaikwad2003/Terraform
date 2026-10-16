##############################################################
# backup_recovery.tf — Centralized Backup Plans & Vault
##############################################################

# KMS encrypted central backup vault
resource "aws_backup_vault" "main" {
  name        = "${var.project_name}-backup-vault"
  kms_key_arn = aws_kms_key.database_key.arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-backup-vault"
  })
}

# IAM Role assumed by AWS Backup service
resource "aws_iam_role" "backup_role" {
  name = "${var.project_name}-backup-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "backup_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup_role.name
}

resource "aws_iam_role_policy_attachment" "restore_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
  role       = aws_iam_role.backup_role.name
}

# Automated multi-tier backup plan with cold storage transition
resource "aws_backup_plan" "production_plan" {
  name = "${var.project_name}-production-backup-plan"

  rule {
    rule_name         = "daily-retained-30-days"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 5 ? * * *)" # Daily at 5:00 UTC

    lifecycle {
      delete_after = 30
    }
  }

  rule {
    rule_name         = "weekly-cold-archive"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 6 ? * 1 *)" # Weekly on Sunday at 6:00 UTC

    lifecycle {
      cold_storage_after = 30
      delete_after       = 365
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-backup-plan"
  })
}

# Resource selection for database and EFS storage
resource "aws_backup_selection" "production_selection" {
  iam_role_arn = aws_iam_role.backup_role.arn
  name         = "${var.project_name}-backup-selection"
  plan_id      = aws_backup_plan.production_plan.id

  resources = [
    aws_efs_file_system.main.arn,
    aws_db_instance.primary.arn
  ]
}
