##############################################################
# FILE 4: iam_roles.tf — IAM Roles, Policies & Users
# Use-case: Manage team permissions using least-privilege IAM.
#            DevOps teams run this daily to onboard/off-board
#            developers, add service roles, and audit access.
##############################################################

# ══════════════════════════════════════════════════════════════
# Developer Group & Users
# ══════════════════════════════════════════════════════════════
variable "developer_users" {
  description = "List of developer IAM usernames to create"
  type        = list(string)
  default     = ["alice", "bob", "charlie"]
}

resource "aws_iam_group" "developers" {
  name = "${var.project_name}-developers"
}

resource "aws_iam_user" "developers" {
  for_each      = toset(var.developer_users)
  name          = each.key
  force_destroy = true
  tags          = { Team = "engineering", Environment = var.environment }
}

resource "aws_iam_user_group_membership" "developers" {
  for_each = toset(var.developer_users)
  user     = aws_iam_user.developers[each.key].name
  groups   = [aws_iam_group.developers.name]
}

# ─── Developer Policy: read-only prod, full-access dev ────────
resource "aws_iam_policy" "developer_policy" {
  name        = "${var.project_name}-developer-policy"
  description = "Least-privilege policy for developers"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadOnlyS3"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2ReadOnly"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "elasticloadbalancing:Describe*",
          "autoscaling:Describe*"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:GetLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      },
      {
        Sid      = "DenyBilling"
        Effect   = "Deny"
        Action   = ["aws-portal:*", "budgets:*"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_group_policy_attachment" "developers" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.developer_policy.arn
}

# ══════════════════════════════════════════════════════════════
# CI/CD Service Role (GitHub Actions / Jenkins)
# ══════════════════════════════════════════════════════════════
variable "github_org"  { default = "my-company" }
variable "github_repo" { default = "my-company-app" }

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "cicd_role" {
  name        = "${var.project_name}-cicd-role"
  description = "Role assumed by CI/CD pipeline"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # GitHub Actions OIDC trust
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "cicd_policy" {
  name        = "${var.project_name}-cicd-policy"
  description = "Permissions needed by CI/CD to deploy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAccess"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECSDeployment"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "iam:PassRole"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3Deploy"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "${aws_s3_bucket.assets.arn}",
          "${aws_s3_bucket.assets.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cicd" {
  role       = aws_iam_role.cicd_role.name
  policy_arn = aws_iam_policy.cicd_policy.arn
}

# ══════════════════════════════════════════════════════════════
# Read-Only Role for Auditors / Security Team
# ══════════════════════════════════════════════════════════════
resource "aws_iam_role" "auditor_role" {
  name        = "${var.project_name}-auditor-role"
  description = "Read-only access for security auditors"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "auditor_readonly" {
  role       = aws_iam_role.auditor_role.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "auditor_security" {
  role       = aws_iam_role.auditor_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

# ─── Outputs ──────────────────────────────────────────────────
output "cicd_role_arn"    { value = aws_iam_role.cicd_role.arn }
output "auditor_role_arn" { value = aws_iam_role.auditor_role.arn }
output "developer_group"  { value = aws_iam_group.developers.name }
