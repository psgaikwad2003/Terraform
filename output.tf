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