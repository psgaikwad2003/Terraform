# AWS Infrastructure with Terraform

Production-grade, modular AWS infrastructure provisioned with clean and idiomatic Terraform HCL.

## Architecture Overview

```
[ CloudFront CDN ]
       │
       ├─── /api/* ───> [ API Gateway (REST) ] ───> [ Lambda Functions ] ───> [ DynamoDB ]
       │
       └─── /* ───────> [ S3 Assets Bucket ]
                               │
[ VPC Networking ] ────────────┴──────────────────────────────────────────────────┐
       │                                                                          │
       ├─── Public Subnets ───> [ Application Load Balancer ]                      │
       │                                   │                                      │
       └─── Private Subnets ──> [ EC2 Auto Scaling Fleet / ECS Fargate ]          │
                                           │                                      │
                                [ PostgreSQL RDS (Multi-AZ) ] ────────────────────┘
```

## Module Structure

| File | Description |
|---|---|
| `provider.tf` | Terraform requirements and AWS provider default tags |
| `variables.tf` | Centralized root input variables and validation rules |
| `main.tf` | Shared local values and environment data sources |
| `vpc_networking.tf` | Multi-AZ VPC, public/private subnets, NAT Gateway, and Flow Logs |
| `security_groups.tf` | Tiered security groups (ALB, Web, DB, Lambda, EFS, Redis, Bastion) |
| `ec2_autoscaling.tf` | Self-healing EC2 Auto Scaling fleet with Launch Template & ALB |
| `ecs_fargate.tf` | ECS Fargate cluster, task definition, and service auto-scaling |
| `rds_database.tf` | PostgreSQL Multi-AZ cluster with read replica and Secrets Manager |
| `s3_storage.tf` | S3 buckets for assets, access logs, and compliance backups |
| `dynamodb.tf` | On-demand DynamoDB tables (items and sessions) with PITR & TTL |
| `lambda_functions.tf` | Serverless Lambda execution roles, handlers, and log groups |
| `api_gateway.tf` | REST API Gateway endpoints, proxy integrations, and stages |
| `cloudfront_cdn.tf` | Global CloudFront CDN with Origin Access Control and security headers |
| `monitoring_alerts.tf` | CloudWatch alarms, operations dashboard, and AWS budget tracking |
| `secrets_manager.tf` | Secrets Manager secrets and SSM Parameter Store configurations |
| `iam_roles.tf` | Least-privilege IAM roles, developer group, and CIS password policy |
| `output.tf` | Consolidated infrastructure output manifest |

## Quick Start

### Prerequisites
- [Terraform >= 1.5.0](https://www.terraform.io/downloads.html)
- AWS CLI configured with administrator or deployment credentials

### Initialize and Validate
```bash
# Initialize Terraform and download providers
terraform init

# Validate configuration syntax and references
terraform validate

# Format HCL files
terraform fmt
```

### Plan and Deploy
```bash
# Review planned infrastructure changes
terraform plan

# Apply infrastructure deployment
terraform apply
```
