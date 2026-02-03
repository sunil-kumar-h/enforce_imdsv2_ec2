provider "aws" {
  region = "us-east-1" # change as needed
}

# 🔹 IAM Role for Lambda
resource "aws_iam_role" "lambda_exec_role" {
  name = "TerminateNonIMDSv2Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

datadog_container = {
    name      = "datadog-agent"
    image     = "public.ecr.aws/datadog/agent:7.72.1"
    essential = true
}

{
      name      = "fluent-bit"
      image     = "public.ecr.aws/aws-observability/aws-for-fluent-bit:3.0.1"
      essential = true
      firelensConfiguration = {
        type = "fluentbit",
        options = {
          "enable-ecs-log-metadata" : "true",
          "config-file-type" : "file",
          "config-file-value" : "/fluent-bit/configs/parse-json.conf"
        }
      }

# 🔹 IAM Policy: Allow termination + logging
resource "aws_iam_role_policy" "terminate_policy" {
  name   = "AllowTerminateAndLogs"
  role   = aws_iam_role.lambda_exec_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ec2:TerminateInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeRegions"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

# 🔹 Lambda Function
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda.zip"
  source {
    content  = file("${path.module}/terminate_non_imdsv2.py")
    filename = "terminate.py"
  }
}

resource "aws_lambda_function" "terminate_lambda" {
  function_name = "TerminateNonIMDSv2"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "terminate.lambda_handler"
  runtime       = "python3.12"
  filename      = data.archive_file.lambda_zip.output_path
  timeout       = 60
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

# 🔹 EventBridge Rule for RunInstances
resource "aws_cloudwatch_event_rule" "ec2_launch_rule" {
  name        = "TerminateOnRunInstances"
  event_pattern = jsonencode({
    source      = ["aws.ec2"],
    "detail-type" = ["AWS API Call via CloudTrail"],
    detail      = {
      eventName = ["RunInstances"]
    }
  })
}

# 🔹 EventBridge Target
resource "aws_cloudwatch_event_target" "send_to_lambda" {
  rule      = aws_cloudwatch_event_rule.ec2_launch_rule.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.terminate_lambda.arn
}

# 🔹 Permission for EventBridge to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.terminate_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ec2_launch_rule.arn
}
