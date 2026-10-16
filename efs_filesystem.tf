##############################################################
# efs_filesystem.tf — Multi-AZ Elastic File System (EFS)
##############################################################

# Scalable shared persistent storage for containers and EC2 instances
resource "aws_efs_file_system" "main" {
  creation_token   = "${var.project_name}-efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true
  kms_key_id       = aws_kms_key.storage_key.arn

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-efs"
  })
}

# Automatic daily backups managed via AWS Backup
resource "aws_efs_backup_policy" "policy" {
  file_system_id = aws_efs_file_system.main.id

  backup_policy {
    status = "ENABLED"
  }
}

# Mount targets created across private subnets in distinct availability zones
resource "aws_efs_mount_target" "mount_targets" {
  count           = length(aws_subnet.private)
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs_sg.id]
}

# Access point for container and application workload directory scoping
resource "aws_efs_access_point" "app_data" {
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/app/data"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "0755"
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-efs-access-point"
  })
}
