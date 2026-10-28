##############################################################
# route53_dns.tf — DNS Routing & SSL/TLS Certificate Management
##############################################################

# Private Hosted Zone for secure internal microservice discovery
resource "aws_route53_zone" "internal" {
  name    = "corp.${var.project_name}.internal"
  comment = "Private zone for service discovery and internal VPC routing"

  vpc {
    vpc_id = aws_vpc.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-internal-dns"
  })
}

# Internal service record pointing to primary database
resource "aws_route53_record" "db_internal" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "db.corp.${var.project_name}.internal"
  type    = "CNAME"
  ttl     = 300
  records = [aws_db_instance.primary.address]
}

# Internal service record pointing to Redis cache
resource "aws_route53_record" "redis_internal" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "cache.corp.${var.project_name}.internal"
  type    = "CNAME"
  ttl     = 300
  records = [aws_elasticache_replication_group.redis_cluster.primary_endpoint_address]
}

# Internal service record pointing to EFS filesystem
resource "aws_route53_record" "efs_internal" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "efs.corp.${var.project_name}.internal"
  type    = "CNAME"
  ttl     = 300
  records = [aws_efs_file_system.main.dns_name]
}

# ACM SSL/TLS Certificate for secure HTTPS transport
resource "aws_acm_certificate" "app_cert" {
  domain_name       = "api.${var.project_name}.com"
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.project_name}.com"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-acm-cert"
  })
}

# Route 53 Health Check monitoring application availability
resource "aws_route53_health_check" "app_health" {
  fqdn              = aws_lb.main.dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/health"
  failure_threshold = "3"
  request_interval  = "30"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-r53-healthcheck"
  })
}

# Outputs
output "route53_internal_zone_id" {
  description = "ID of the private internal Route 53 zone"
  value       = aws_route53_zone.internal.zone_id
}

output "route53_internal_zone_name" {
  description = "Domain name of the private internal Route 53 zone"
  value       = aws_route53_zone.internal.name
}

output "acm_certificate_arn" {
  description = "ARN of the provisioned ACM TLS certificate"
  value       = aws_acm_certificate.app_cert.arn
}

