provider "aws" {
  region     = var.AWS_REGION
  secret_key = var.AWS_SECRET_KEY
  access_key = var.AWS_ACCESS_KEY
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "lambda_assume_role_policy_document" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_execution_policy_document" {

  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions   = ["sqs:SendMessage"]
    effect    = "Allow"
    resources = [aws_sqs_queue.success_queue.arn,aws_sqs_queue.failure_queue.arn]
  }
}

resource "aws_iam_policy" "lambda_execution_policy" {
  name   = "lamdba-execution-policy"
  policy = data.aws_iam_policy_document.lambda_execution_policy_document.json
}

resource "aws_iam_role" "lambda_execution_role" {
  name                = "lambda-execution-role"
  assume_role_policy  = data.aws_iam_policy_document.lambda_assume_role_policy_document.json
  managed_policy_arns = [aws_iam_policy.lambda_execution_policy.arn]
}

resource "aws_lambda_function" "lambda" {
  filename         = var.SOURCE_FILE_NAME
  function_name    = var.LAMBDA_NAME
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = var.LAMBDA_HANDLER
  source_code_hash = filebase64sha256("${var.SOURCE_FILE_PATH}/${var.SOURCE_FILE_NAME}")
  runtime          = var.LAMBDA_RUN_TIME
}

resource "aws_cloudwatch_log_group" "loggroup" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 14
}


data "aws_iam_policy_document" "queue_policy_document" {
  statement {
    actions = ["sqs:*"]
    effect  = "Allow"
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }
    resources = ["arn:aws:sqs:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}"]
  }
}

resource "aws_sqs_queue" "success_queue" {
  name                       = "${var.AWS_SQS_NAME}-success"
  visibility_timeout_seconds = "30"
  message_retention_seconds  = "345600"
  max_message_size           = "262144"
  delay_seconds              = "0"
  receive_wait_time_seconds  = "0"
}

resource "aws_sqs_queue_policy" "success_queue_policy" {
  queue_url = aws_sqs_queue.success_queue.id
  policy    = data.aws_iam_policy_document.queue_policy_document.json
}

resource "aws_sqs_queue" "failure_queue" {
  name                       = "${var.AWS_SQS_NAME}-failure"
  visibility_timeout_seconds = "30"
  message_retention_seconds  = "345600"
  max_message_size           = "262144"
  delay_seconds              = "0"
  receive_wait_time_seconds  = "0"
}

resource "aws_sqs_queue_policy" "failure_queue_policy" {
  queue_url = aws_sqs_queue.failure_queue.id
  policy    = data.aws_iam_policy_document.queue_policy_document.json
}


resource "aws_lambda_function_event_invoke_config" "lambda_function_event_invoke_config" {
  function_name          = aws_lambda_function.lambda.arn
  maximum_retry_attempts = 2
  destination_config {
    on_failure {
      destination = aws_sqs_queue.failure_queue.arn
    }

    on_success {
      destination = aws_sqs_queue.success_queue.arn
    }
  }
}