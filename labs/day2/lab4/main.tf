# Lab 2.4 · Tripwires as Code — deploy into skyfortress-prod (or any member account).
#   terraform init && terraform apply -var alert_email=you@example.com
# Confirm the SNS subscription email, then trip the wires.

terraform {
  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
  }
}

provider "aws" {
  region = "us-east-1" # IAM, STS & console sign-in events land here
}

variable "alert_email" {
  type        = string
  description = "Where tripwire alerts go"
}

locals {
  patterns = { for f in fileset("${path.module}/patterns", "*.json") : trimsuffix(f, ".json") => file("${path.module}/patterns/${f}") }
  tags     = { lab = "skyfortress-d2", owner = "owlsley" }
}

resource "aws_sns_topic" "tripwires" {
  name              = "skyfortress-tripwires"
  kms_master_key_id = "alias/aws/sns"
  tags              = local.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.tripwires.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

data "archive_file" "detector" {
  type        = "zip"
  source_file = "${path.module}/detector.py"
  output_path = "${path.module}/.build/detector.zip"
}

resource "aws_iam_role" "detector" {
  name = "skyfortress-tripwire-detector"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.detector.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "publish" {
  role = aws_iam_role.detector.id
  name = "publish-tripwires"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sns:Publish", Resource = aws_sns_topic.tripwires.arn }]
  })
}

resource "aws_lambda_function" "detector" {
  function_name    = "skyfortress-tripwire-detector"
  role             = aws_iam_role.detector.arn
  runtime          = "python3.12"
  handler          = "detector.handler"
  filename         = data.archive_file.detector.output_path
  source_code_hash = data.archive_file.detector.output_base64sha256
  timeout          = 10
  environment { variables = { SNS_TOPIC_ARN = aws_sns_topic.tripwires.arn } }
  tags = local.tags
}

resource "aws_cloudwatch_event_rule" "tripwire" {
  for_each      = local.patterns
  name          = "skyfortress-${each.key}"
  description   = "Skyfortress tripwire: ${each.key}"
  event_pattern = each.value
  tags          = local.tags
}

resource "aws_cloudwatch_event_target" "tripwire" {
  for_each = local.patterns
  rule     = aws_cloudwatch_event_rule.tripwire[each.key].name
  arn      = aws_lambda_function.detector.arn
}

resource "aws_lambda_permission" "events" {
  for_each      = local.patterns
  statement_id  = "events-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.detector.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.tripwire[each.key].arn
}

output "rules" { value = [for r in aws_cloudwatch_event_rule.tripwire : r.name] }
output "topic" { value = aws_sns_topic.tripwires.arn }
