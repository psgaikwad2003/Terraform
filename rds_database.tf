##############################################################
# rds_database.tf — RDS PostgreSQL with Read Replica & Secrets
##############################################################

variable "db_name" {
  description = "Name of the default database to create"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for database administration"
  type        = string
  default     = "dbadmin"
}

variable "db_instance_class" {
  description = "Compute and memory capacity instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "Allocated storage in gigabytes"
  type        = number
  default     = 100
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "db_backup_retention" {
  description = "Days of automated backup retention"
  type        = number
  default     = 7
}

# DB Subnet Group across private subnets
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow PostgreSQL access from EC2 application servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from app servers"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# KMS Key for Database Storage Encryption
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS storage encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-rds-kms"
  }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project_name}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# Database Master Password & Secret
resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%^&*()-_=+[]<>?"
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project_name}/rds/db-password"
  kms_key_id              = aws_kms_key.rds.arn
  recovery_window_in_days = 7

  tags = {
    Name = "${var.project_name}-db-secret"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    host     = aws_db_instance.primary.address
    port     = 5432
    dbname   = var.db_name
  })
}

# Parameter Group
resource "aws_db_parameter_group" "postgres" {
  name   = "${var.project_name}-pg-params"
  family = "postgres15"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }
}

# Primary Multi-AZ RDS Instance
resource "aws_db_instance" "primary" {
  identifier            = "${var.project_name}-primary"
  engine                = "postgres"
  engine_version        = var.db_engine_version
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = 500
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.postgres.name

  multi_az                  = true
  publicly_accessible       = false
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-final-snapshot"

  backup_retention_period = var.db_backup_retention
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn

  auto_minor_version_upgrade          = true
  copy_tags_to_snapshot               = true
  iam_database_authentication_enabled = true

  tags = {
    Name = "${var.project_name}-rds-primary"
  }
}

# Read Replica RDS Instance
resource "aws_db_instance" "replica" {
  identifier          = "${var.project_name}-replica"
  instance_class      = var.db_instance_class
  replicate_source_db = aws_db_instance.primary.identifier
  storage_encrypted   = true

  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.postgres.name

  auto_minor_version_upgrade          = true
  copy_tags_to_snapshot               = true
  skip_final_snapshot                 = true
  iam_database_authentication_enabled = true

  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring.arn

  tags = {
    Name = "${var.project_name}-rds-replica"
  }
}

# Enhanced Monitoring IAM Role
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Outputs
output "rds_primary_endpoint" {
  description = "Connection endpoint for the primary database"
  value       = aws_db_instance.primary.endpoint
}

output "rds_replica_endpoint" {
  description = "Connection endpoint for the read replica"
  value       = aws_db_instance.replica.endpoint
}

output "rds_db_secret_arn" {
  description = "ARN of the Secrets Manager secret for RDS master credentials"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "rds_database_name" {
  description = "Database name"
  value       = aws_db_instance.primary.db_name
}
