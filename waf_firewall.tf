##############################################################
# waf_firewall.tf — AWS WAFv2 Web Application Firewall
##############################################################

# Explicit IP block list set
resource "aws_wafv2_ip_set" "blocked_ips" {
  name               = "${var.project_name}-blocked-ips"
  description        = "Reputation-based and manually blocked IP addresses"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = ["198.51.100.0/24", "203.0.113.0/24"]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-blocked-ips"
  })
}

# Regional Web ACL defending ALB endpoints against common exploits and DDoS
resource "aws_wafv2_web_acl" "regional_acl" {
  name        = "${var.project_name}-regional-waf"
  description = "Regional WAF protecting public load balancers and APIs"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Rule 1: Block suspicious IPs
  rule {
    name     = "BlockKnownBadIPs"
    priority = 1

    action {
      block {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.blocked_ips.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockKnownBadIPsMetric"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: IP Rate Limiting (DDoS & Brute-force mitigation)
  rule {
    name     = "RateLimitRule"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitMetric"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: AWS Managed Common Rule Set (OWASP Top 10)
  rule {
    name     = "AWSManagedCommonRules"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedCommonRulesMetric"
      sampled_requests_enabled   = true
    }
  }

  # Rule 4: AWS Managed SQL Injection Protections
  rule {
    name     = "AWSManagedSQLiRules"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedSQLiRulesMetric"
      sampled_requests_enabled   = true
    }
  }

  # Rule 5: AWS Managed IP Reputation List
  rule {
    name     = "AWSManagedIPReputationList"
    priority = 5

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedIPReputationMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf-metric"
    sampled_requests_enabled   = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-regional-waf"
  })
}

# Association with Public Application Load Balancer
resource "aws_wafv2_web_acl_association" "alb_waf" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.regional_acl.arn
}
