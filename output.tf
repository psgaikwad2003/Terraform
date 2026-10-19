##############################################################
# output.tf — Primary Infrastructure Stack Outputs
##############################################################

# Core Environment Identifiers
output "deployment_environment" {
  description = "The active deployment environment"
  value       = var.environment
}

output "deployment_project_name" {
  description = "The project name prefix"
  value       = var.project_name
}

# Networking
output "vpc_id" {
  description = "ID of the core VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

# Security Groups
output "alb_security_group_id" {
  description = "Security Group ID assigned to Application Load Balancer"
  value       = aws_security_group.alb_sg.id
}

output "web_tier_security_group_id" {
  description = "Security Group ID assigned to web tier compute resources"
  value       = aws_security_group.web_sg.id
}

output "redis_tier_security_group_id" {
  description = "Security Group ID assigned to ElastiCache Redis cluster"
  value       = aws_security_group.redis_sg.id
}

# Entrypoint Endpoints
output "cloudfront_endpoint" {
  description = "Domain name for CloudFront CDN distribution"
  value       = aws_cloudfront_distribution.main_cdn.domain_name
}

output "api_gateway_endpoint" {
  description = "Public invoke URL for API Gateway"
  value       = aws_api_gateway_stage.prod_stage.invoke_url
}

output "ec2_alb_dns" {
  description = "DNS name of the EC2 fleet Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "ecs_alb_dns" {
  description = "DNS name of the ECS Fargate Application Load Balancer"
  value       = aws_lb.ecs_alb.dns_name
}

output "rds_endpoint" {
  description = "Endpoint of the primary RDS PostgreSQL database"
  value       = aws_db_instance.primary.endpoint
}

# KMS Encryption
output "kms_storage_key_arn" {
  description = "ARN of the customer managed key for storage encryption"
  value       = aws_kms_key.storage_key.arn
}

output "kms_database_key_arn" {
  description = "ARN of the customer managed key for database encryption"
  value       = aws_kms_key.database_key.arn
}

# Caching & Persistent Storage
output "elasticache_redis_endpoint" {
  description = "Primary endpoint address for the ElastiCache Redis cluster"
  value       = aws_elasticache_replication_group.redis_cluster.primary_endpoint_address
}

output "efs_file_system_id" {
  description = "ID of the shared multi-AZ Elastic File System"
  value       = aws_efs_file_system.main.id
}

# Messaging & Event-Driven Architecture
output "sqs_tasks_queue_url" {
  description = "URL of the primary SQS asynchronous tasks queue"
  value       = aws_sqs_queue.app_queue.id
}

output "sqs_orders_fifo_queue_url" {
  description = "URL of the transactional FIFO orders queue"
  value       = aws_sqs_queue.orders_fifo_queue.id
}

output "sns_notifications_topic_arn" {
  description = "ARN of the SNS event notification topic"
  value       = aws_sns_topic.notifications.arn
}

output "eventbridge_bus_arn" {
  description = "ARN of the custom application EventBridge bus"
  value       = aws_cloudwatch_event_bus.app_bus.arn
}

# Security, WAF & Governance
output "waf_web_acl_arn" {
  description = "ARN of the AWS WAFv2 regional Web ACL"
  value       = aws_wafv2_web_acl.regional_acl.arn
}

output "backup_vault_arn" {
  description = "ARN of the central AWS Backup vault"
  value       = aws_backup_vault.main.arn
}

output "cloudtrail_arn" {
  description = "ARN of the multi-region CloudTrail audit trail"
  value       = aws_cloudtrail.main.arn
}

# Workflow Orchestration & Analytics
output "step_functions_state_machine_arn" {
  description = "ARN of the order processing Step Functions state machine"
  value       = aws_sfn_state_machine.order_workflow.arn
}

output "athena_workgroup_name" {
  description = "Name of the Athena interactive query workgroup"
  value       = aws_athena_workgroup.analytics_workgroup.name
}

output "athena_workgroup_arn" {
  description = "ARN of the Athena interactive query workgroup"
  value       = aws_athena_workgroup.analytics_workgroup.arn
}

output "glue_catalog_database_name" {
  description = "Name of the central Glue Data Catalog database"
  value       = aws_glue_catalog_database.analytics_db.name
}