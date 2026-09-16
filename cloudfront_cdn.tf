# CloudFront CDN Configuration
# Distributes static and dynamic content globally with caching and HTTPS

# Origin Access Control for S3
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "s3-origin-access-control"
  description                       = "OAC for S3 static assets"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Cache Policy - Optimized for static assets
resource "aws_cloudfront_cache_policy" "static_assets" {
  name        = "static-assets-cache-policy"
  comment     = "Cache policy for static assets with long TTL"
  default_ttl = 86400    # 1 day
  max_ttl     = 31536000 # 1 year
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main_cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Main CDN distribution"
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # US, Canada, Europe only

  # S3 Static Assets Origin
  origin {
    domain_name              = aws_s3_bucket.main.bucket_regional_domain_name
    origin_id                = "S3-static-assets"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }

  # API Gateway Origin
  origin {
    domain_name = replace(aws_api_gateway_deployment.main.invoke_url, "https://", "")
    origin_id   = "APIGateway-backend"
    origin_path = "/prod"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default cache behavior - serves from S3
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-static-assets"
    cache_policy_id        = aws_cloudfront_cache_policy.static_assets.id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  # API path behavior - forwards to API Gateway
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "APIGateway-backend"
    viewer_protocol_policy = "https-only"
    compress               = true

    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled managed policy

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type"]
      cookies {
        forward = "none"
      }
    }
  }

  # Custom error responses for SPA routing
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    # Uncomment below when using a custom domain with ACM certificate:
    # acm_certificate_arn      = aws_acm_certificate.main.arn
    # ssl_support_method       = "sni-only"
    # minimum_protocol_version = "TLSv1.2_2021"
  }

  # WAF Web ACL association (optional)
  # web_acl_id = aws_wafv2_web_acl.main.arn

  tags = {
    Name        = "main-cdn"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

# Output the CloudFront domain
output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main_cdn.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.main_cdn.id
}
