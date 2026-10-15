##############################################################
# monitoring_alerts.tf — CloudWatch Monitoring, Alarms & Budgets
##############################################################

variable "alert_email" {
  description = "Recipient email address for operations notifications"
  type        = string
  default     = "devops-team@mycompany.com"
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for channel notifications"
  type        = string
  default     = ""
}

variable "monthly_budget_limit" {
  description = "Monthly AWS spending threshold in USD"
  type        = number
  default     = 1000
}

variable "cpu_alarm_threshold" {
  description = "EC2 CPU utilization alarm threshold percentage"
  type        = number
  default     = 80
}

variable "rds_cpu_threshold" {
  description = "RDS CPU utilization alarm threshold percentage"
  type        = number
  default     = 75
}

variable "alb_5xx_threshold" {
  description = "ALB 5xx error count alarm threshold"
  type        = number
  default     = 10
}

# SNS Alerting Topic
resource "aws_sns_topic" "alerts" {
  name              = "${var.project_name}-alerts"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name = "${var.project_name}-alerts-topic"
  }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/app/${var.project_name}"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-log-group"
  }
}

# EC2 & ASG Alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-high-cpu"
  alarm_description   = "EC2 ASG CPU utilization exceeded ${var.cpu_alarm_threshold}%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn, aws_autoscaling_policy.cpu_tracking.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  tags = {
    Name = "${var.project_name}-high-cpu-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "asg_min_capacity" {
  alarm_name          = "${var.project_name}-asg-min-capacity"
  alarm_description   = "ASG is at minimum capacity"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "GroupInServiceInstances"
  namespace           = "AWS/AutoScaling"
  period              = 300
  statistic           = "Minimum"
  threshold           = var.min_size
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
}

# ALB Alarms
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.project_name}-alb-5xx-errors"
  alarm_description   = "ALB 5xx error rate is elevated"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = var.alb_5xx_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.project_name}-unhealthy-hosts"
  alarm_description   = "One or more ALB target hosts are unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    TargetGroup  = aws_lb_target_group.app.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }
}

# RDS Alarms
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.project_name}-rds-high-cpu"
  alarm_description   = "RDS CPU utilization > ${var.rds_cpu_threshold}%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = var.rds_cpu_threshold
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.primary.identifier
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name          = "${var.project_name}-rds-low-storage"
  alarm_description   = "RDS free storage is below 10 GB"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Minimum"
  threshold           = 10000000000
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.primary.identifier
  }
}

# ECS Service Alarm
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${var.project_name}-ecs-high-memory"
  alarm_description   = "ECS Service memory utilization exceeded 85%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 85
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.main_app.name
  }
}

# CloudWatch Operations Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-operations"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "EC2 CPU Utilization"
          view   = "timeSeries"
          period = 60
          metrics = [[
            "AWS/EC2", "CPUUtilization",
            "AutoScalingGroupName", aws_autoscaling_group.app.name
          ]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ALB Request Count & 5xx Errors"
          view   = "timeSeries"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.main.arn_suffix]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "RDS CPU & Connections"
          view   = "timeSeries"
          period = 60
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.primary.identifier],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", aws_db_instance.primary.identifier]
          ]
        }
      },
      {
        type   = "alarm"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title = "Active Alarms"
          alarms = [
            aws_cloudwatch_metric_alarm.high_cpu.arn,
            aws_cloudwatch_metric_alarm.alb_5xx_errors.arn,
            aws_cloudwatch_metric_alarm.unhealthy_hosts.arn,
            aws_cloudwatch_metric_alarm.rds_cpu.arn,
            aws_cloudwatch_metric_alarm.rds_free_storage.arn,
            aws_cloudwatch_metric_alarm.ecs_memory_high.arn
          ]
        }
      }
    ]
  })
}

# Cost Control Budget
resource "aws_budgets_budget" "monthly" {
  name         = "${var.project_name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_limit)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}

# Outputs
output "sns_alerts_arn" {
  description = "ARN of the SNS alerts topic"
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_name" {
  description = "CloudWatch operations dashboard name"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}
