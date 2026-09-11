##############################################################
# FILE 5: rds_database.tf — RDS PostgreSQL with Read Replica
# Use-case: Provision a managed database cluster with Multi-AZ
#            for high availability, automated backups, read
#            replica for reporting, and Secrets Manager rotation.
##############################################################

# ─── Variables ───────────────────────────────────────────────
variable "db_name"             { default = "appdb" }
variable "db_username"         { default = "dbadmin" }
variable "db_instance_class"   { default = "db.t3.medium" }
variable "db_allocated_storage" { default = 100 }
variable "db_engine_version"   { default = "15.4" }
variable "db_backup_retention" { default = 7 }

# ─── DB Subnet Group ─────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id
  tags       = { Name = "${var.project_name}-db-subnet-group" }
}

# ─── Security Group — RDS ────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "RDS: allow access only from EC2 app servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from app"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-rds-sg" }
}

# ─── KMS Key for RDS encryption ──────────────────────────────
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  tags                    = { Name = "${var.project_name}-rds-kms" }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project_name}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# ─── DB Password in Secrets Manager ─────────────────────────
resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%^&*()-_=+[]<>?"
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project_name}/rds/db-password"
  kms_key_id              = aws_kms_key.rds.arn
  recovery_window_in_days = 7
  tags                    = { Name = "${var.project_name}-db-secret" }
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

# ─── DB Parameter Group (tuned for web apps) ─────────────────
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
    value = "1000"  # Log queries slower than 1 second
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }
}

# ─── Primary RDS Instance (Multi-AZ) ─────────────────────────
resource "aws_db_instance" "primary" {
  identifier             = "${var.project_name}-primary"
  engine                 = "postgres"
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  max_allocated_storage  = 500
  storage_type           = "gp3"
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.rds.arn

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.postgres.name

  multi_az               = true
  publicly_accessible    = false
  deletion_protection    = true
  skip_final_snapshot    = false
  final_snapshot_identifier = "${var.project_name}-final-snapshot"

  backup_retention_period   = var.db_backup_retention
  backup_window             = "03:00-04:00"
  maintenance_window        = "mon:04:00-mon:05:00"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled    = true
  performance_insights_retention_period = 7
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  auto_minor_version_upgrade = true

  tags = { Name = "${var.project_name}-rds-primary" }
}

# ─── Read Replica (for reporting/analytics queries) ───────────
resource "aws_db_instance" "replica" {
  identifier          = "${var.project_name}-replica"
  instance_class      = var.db_instance_class
  replicate_source_db = aws_db_instance.primary.identifier
  storage_encrypted   = true

  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.postgres.name

  auto_minor_version_upgrade = true
  skip_final_snapshot        = true

  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring.arn

  tags = { Name = "${var.project_name}-rds-replica" }
}

# ─── Enhanced Monitoring Role ─────────────────────────────────
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

# ─── Outputs ──────────────────────────────────────────────────
output "rds_primary_endpoint" { value = aws_db_instance.primary.endpoint }
output "rds_replica_endpoint" { value = aws_db_instance.replica.endpoint }
output "db_secret_arn"        { value = aws_secretsmanager_secret.db_password.arn }
output "db_name"              { value = aws_db_instance.primary.db_name }
