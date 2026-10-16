##############################################################
# elasticache_redis.tf — Distributed In-Memory Caching Tier
##############################################################

# Subnet group spanning across private subnets for multi-AZ
resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name        = "${var.project_name}-redis-subnet-group"
  description = "Private subnet group for ElastiCache Redis cluster"
  subnet_ids  = aws_subnet.private[*].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-redis-subnets"
  })
}

# Redis 7 parameter group with production optimizations
resource "aws_elasticache_parameter_group" "redis_params" {
  name   = "${var.project_name}-redis7-params"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "volatile-lru"
  }

  parameter {
    name  = "notify-keyspace-events"
    value = "Ex"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-redis-params"
  })
}

# Highly available Redis replication group with automatic failover
resource "aws_elasticache_replication_group" "redis_cluster" {
  replication_group_id = "${var.project_name}-redis"
  description          = "Redis replication group for session cache and query caching"
  node_type            = "cache.t4g.small"
  num_cache_clusters   = 2
  port                 = 6379

  parameter_group_name = aws_elasticache_parameter_group.redis_params.name
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids   = [aws_security_group.redis_sg.id]

  automatic_failover_enabled = true
  multi_az_enabled           = true

  at_rest_encryption_enabled = true
  kms_key_id                 = aws_kms_key.database_key.arn

  snapshot_retention_limit   = 7
  snapshot_window            = "03:00-04:00"
  maintenance_window         = "sun:05:00-sun:06:00"
  auto_minor_version_upgrade = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-redis-cluster"
  })
}
