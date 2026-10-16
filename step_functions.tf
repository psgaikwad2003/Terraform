##############################################################
# step_functions.tf — Serverless Workflow State Machine
##############################################################

# CloudWatch Log Group for recording workflow execution logs
resource "aws_cloudwatch_log_group" "sfn_logs" {
  name              = "/aws/vendedlogs/states/${var.project_name}-order-workflow"
  retention_in_days = 30

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sfn-logs"
  })
}

# IAM Role assumed by AWS Step Functions
resource "aws_iam_role" "sfn_execution_role" {
  name = "${var.project_name}-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "sfn_policy" {
  name = "${var.project_name}-sfn-policy"
  role = aws_iam_role.sfn_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.app_queue.arn
      }
    ]
  })
}

# Step Functions State Machine orchestrating complex multi-step workflows
resource "aws_sfn_state_machine" "order_workflow" {
  name     = "${var.project_name}-order-processing-workflow"
  role_arn = aws_iam_role.sfn_execution_role.arn

  definition = jsonencode({
    Comment = "Enterprise Order Fulfillment and Transaction Workflow"
    StartAt = "ValidateOrder"
    States = {
      ValidateOrder = {
        Type = "Pass"
        Result = {
          status    = "VALIDATED"
          validated = true
        }
        ResultPath = "$.validationResult"
        Next       = "ProcessPayment"
      }
      ProcessPayment = {
        Type = "Pass"
        Result = {
          paymentStatus = "SUCCESS"
          transactionId = "tx-994829"
        }
        ResultPath = "$.paymentResult"
        Next       = "DispatchNotification"
      }
      DispatchNotification = {
        Type     = "Task"
        Resource = "arn:aws:states:::sqs:sendMessage"
        Parameters = {
          QueueUrl = aws_sqs_queue.app_queue.id
          MessageBody = {
            "orderId.$" = "$.orderId"
            "status"    = "CONFIRMED"
          }
        }
        Next = "WorkflowCompleted"
      }
      WorkflowCompleted = {
        Type = "Succeed"
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn_logs.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-order-workflow"
  })
}
