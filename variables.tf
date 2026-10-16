variable "aws_region" {
  description = "Target AWS deployment region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name (dev, staging, production)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "The environment must be one of: dev, staging, production."
  }
}

variable "project_name" {
  description = "Project name prefix used for resource naming and tagging"
  type        = string
  default     = "my-company-app"
}

variable "cost_center" {
  description = "Cost allocation tag identifier"
  type        = string
  default     = "engineering"
}

variable "vpc_cidr" {
  description = "CIDR block for the Virtual Private Cloud"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "enable_dns_support" {
  description = "Enable DNS support for the VPC"
  type        = bool
  default     = true
}

variable "redis_node_type" {
  description = "Compute and memory capacity node type for ElastiCache Redis cluster"
  type        = string
  default     = "cache.t4g.small"
}

variable "backup_retention_days" {
  description = "Number of days to retain automated daily backups"
  type        = number
  default     = 30
}

variable "waf_rate_limit" {
  description = "Maximum number of requests permitted per 5-minute evaluation period per IP"
  type        = number
  default     = 2000
}

variable "custom_domain_name" {
  description = "Custom root domain name for API endpoints and Route 53 zones"
  type        = string
  default     = "example.com"
}