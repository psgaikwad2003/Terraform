# AWS Infrastructure with Terraform

Production-grade, modular AWS infrastructure provisioned with clean and idiomatic Terraform HCL.

## Architecture Overview

```
                      [ Route 53 DNS / ACM SSL ]
                                   │
                           [ AWS WAFv2 Shield ]
                                   │
                         [ CloudFront CDN ]
                                   │
        ┌──────────────────────────┴──────────────────────────┐
        │                                                     │
        ▼                                                     ▼
 [ API Gateway REST ]                                 [ S3 Assets Bucket ]
        │                                                     │
 [ Lambda Functions ]                                         │
        │                                                     │
   [ DynamoDB ]                                               │
                                                              │
[ VPC Networking (Multi-AZ) ] ────────────────────────────────┴──────────┐
        │                                                                │
        ├─── Public Subnets ───> [ Application Load Balancers ]           │
        │                                   │                            │
        └─── Private Subnets ──> [ EC2 Fleet / ECS Fargate ]             │
                                       │       │       │                 │
              ┌────────────────────────┘       │       └─────────────┐   │
              ▼                                ▼                     ▼   │
     [ RDS PostgreSQL ]               [ ElastiCache Redis ]     [ EFS Mounts ]
              │                                │                     │
              └────────────────────────────────┴─────────────────────┘
                                   │
     [ Auth & Identity: Amazon Cognito User Pool / Client / Identity Pool ]
                                    │
      [ Streaming & Events: Kinesis Streams & Firehose / SQS / SNS / EventBridge ]
                                   │
     [ Governance & Ops: AWS Backup / CloudTrail / AWS Config / SSM / KMS ]
                                   │
     [ Analytics Lake: AWS Glue Catalog / Crawler / Amazon Athena ]
```

## Module Structure

| File | Description |
|---|---|
| `provider.tf` | Terraform requirements and AWS provider default tags |
| `variables.tf` | Centralized root input variables and validation rules |
| `main.tf` | Shared local values and environment data sources |
| `vpc_networking.tf` | Multi-AZ VPC, public/private subnets, NAT Gateway, and Flow Logs |
| `vpc_endpoints.tf` | VPC Interface Endpoints (SSM, Logs) and S3 / DynamoDB Gateway Endpoints |
| `security_groups.tf` | Tiered security groups (ALB, Web, DB, Lambda, EFS, Redis, Bastion) |
| `kms_encryption.tf` | Customer Managed Keys (CMK) with automated rotation for storage and databases |
| `ec2_autoscaling.tf` | Self-healing EC2 Auto Scaling fleet with Launch Template & ALB |
| `ecs_fargate.tf` | ECS Fargate cluster, task definition, and service auto-scaling |
| `rds_database.tf` | PostgreSQL Multi-AZ cluster with read replica and Secrets Manager |
| `elasticache_redis.tf` | ElastiCache Redis replication group with automatic failover and multi-AZ |
| `efs_filesystem.tf` | Elastic File System (EFS) with access points and lifecycle archive policies |
| `s3_storage.tf` | S3 buckets for assets, access logs, and compliance backups |
| `dynamodb.tf` | On-demand DynamoDB tables with Point-in-Time Recovery, TTL, and CDC Streams |
| `cognito_identity.tf` | Amazon Cognito User Pool, app client, hosted UI domain, and federated Identity Pool |
| `kinesis_streaming.tf` | Kinesis Data Stream with KMS encryption and Firehose delivery stream targeting Data Lake S3 |
| `sqs_sns_messaging.tf` | SQS queues with DLQs, FIFO queue, and SNS pub-sub topic integration |
| `eventbridge_events.tf` | Custom EventBridge bus, event replay archive, and multi-target rules |
| `lambda_functions.tf` | Serverless Lambda execution roles, handlers, and log groups |
| `step_functions.tf` | Step Functions state machine orchestrating transactional workflows |
| `api_gateway.tf` | REST API Gateway endpoints, proxy integrations, and stages |
| `route53_dns.tf` | Route 53 private hosted zone, internal DNS records (DB, Redis, EFS), and ACM certificates |
| `cloudfront_cdn.tf` | Global CloudFront CDN with Origin Access Control and security headers |
| `waf_firewall.tf` | AWS WAFv2 regional Web ACL protecting EC2 & ECS ALBs with rate limiting and OWASP rules |
| `backup_recovery.tf` | Centralized AWS Backup vault and plans protecting RDS, EFS, and DynamoDB |
| `cloudtrail_audit.tf` | Multi-region CloudTrail auditing with secure encrypted S3 bucket and CloudWatch logs |
| `aws_config_governance.tf` | AWS Config configuration recorder, delivery channel, and compliance rules (EBS, S3, RDS) |
| `ssm_automation.tf` | Systems Manager parameter store configs and fleet maintenance windows |
| `cicd_pipeline.tf` | Continuous integration and deployment via AWS CodePipeline & CodeBuild |
| `glue_athena_analytics.tf` | Data lake bucket, Glue Data Catalog database, crawler, and Athena workgroup |
| `monitoring_alerts.tf` | CloudWatch alarms, operations dashboard, and AWS budget tracking |
| `secrets_manager.tf` | Secrets Manager secrets and SSM Parameter Store configurations |
| `iam_roles.tf` | Least-privilege IAM roles, developer group, and CIS password policy |
| `output.tf` | Consolidated infrastructure output manifest exposing endpoints and ARNs |

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

## Security & Reliability Highlights
- **Identity & Access Management**: Amazon Cognito User Pool with 12+ char password enforcement, verification emails, and federated identity pools.
- **Perimeter Defense**: AWS WAFv2 Web ACL safeguarding both EC2 fleet and ECS container Application Load Balancers against OWASP Top 10 exploits and DDoS attacks.
- **Cost-Optimized VPC Networking**: Dedicated S3 and DynamoDB Gateway VPC endpoints delivering high-throughput internal routing with zero NAT data transfer fees.
- **Comprehensive Stateful Backup**: Centralized AWS Backup schedules safeguarding RDS PostgreSQL, Elastic File Systems (EFS), and DynamoDB tables.
- **Real-Time Data Streaming & CDC**: Encrypted Amazon Kinesis Data Streams and DynamoDB Streams capturing change events and feeding analytical S3 data lakes.
- **Automated Governance**: AWS Config continuous compliance rules enforcing encryption on attached EBS volumes, S3 bucket privacy, and RDS storage encryption.
- **Internal Service Discovery**: Route 53 private hosted zone managing internal CNAME records for RDS, ElastiCache Redis, and EFS storage mount targets.
- **Observability & Auditing**: Multi-region CloudTrail logging streamed to CloudWatch Logs, alongside CloudWatch alarms and budget tracking on a centralized operations dashboard.

