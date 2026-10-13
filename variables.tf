variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
  default     = "my-s3-bucket"
}

variable "key_pair_name" {
  description = "The name of the key pair"
  type        = string
  default     = "my-key-pair"
}

variable "aws_vpc_id" {
  description = "The ID of the VPC"
  type        = string
  default     = "vpc-12345678"
}

variable "aws_igw_id" {
  description = "The ID of the Internet Gateway"
  type        = string
  default     = "igw-12345678"
}

variable "enable_dns_support" {
  description = "Enable DNS support for the VPC"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Deployment environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Name of the project used for resource naming and tagging"
  type        = string
  default     = "my-app"
}

variable "vpc_cidr" {
  description = "CIDR block for the primary Virtual Private Cloud"
  type        = string
  default     = "10.0.0.0/16"
}