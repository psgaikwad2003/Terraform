# ─────────────────────────────────────────────
#  Infrastructure Stack Outputs
# ─────────────────────────────────────────────

output "deployment_environment" {
  description = "The active deployment environment"
  value       = var.environment
}

output "deployment_project_name" {
  description = "The project name prefix"
  value       = var.project_name
}

output "alb_security_group_id" {
  description = "The Security Group ID assigned to Application Load Balancer"
  value       = aws_security_group.alb_sg.id
}

output "web_tier_security_group_id" {
  description = "The Security Group ID assigned to web tier compute resources"
  value       = aws_security_group.web_sg.id
}

output "redis_tier_security_group_id" {
  description = "The Security Group ID assigned to ElastiCache Redis cluster"
  value       = aws_security_group.redis_sg.id
}