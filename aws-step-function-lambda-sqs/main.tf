provider "aws" {
  region     = var.AWS_REGION
  secret_key = var.AWS_SECRET_KEY
  access_key = var.AWS_ACCESS_KEY
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "lambda_execution_policy_document" {

  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    effect    = "Allow"
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "lambda_assume_role_policy_document" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
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

resource "aws_lambda_function" "create_account" {
  filename         = var.CREATE_ACCOUNT_SOURCE_FILE_NAME
  function_name    = "Create-Account"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = var.CREATE_ACCOUNT_LAMBDA_HANDLER
  source_code_hash = filebase64sha256("${var.CREATE_ACCOUNT_SOURCE_FILE_PATH}/${var.CREATE_ACCOUNT_SOURCE_FILE_NAME}")
  runtime          = var.CREATE_ACCOUNT_LAMBDA_RUN_TIME
}

resource "aws_cloudwatch_log_group" "create_account_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.create_account.function_name}"
  retention_in_days = 1
}

resource "aws_lambda_function" "activate_account" {
  filename         = var.ACTIVATE_ACCOUNT_SOURCE_FILE_NAME
  function_name    = "Activate-Account"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = var.ACTIVATE_ACCOUNT_LAMBDA_HANDLER
  source_code_hash = filebase64sha256("${var.ACTIVATE_ACCOUNT_SOURCE_FILE_PATH}/${var.ACTIVATE_ACCOUNT_SOURCE_FILE_NAME}")
  runtime          = var.ACTIVATE_ACCOUNT_LAMBDA_RUN_TIME
}

resource "aws_cloudwatch_log_group" "activate_account_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.activate_account.function_name}"
  retention_in_days = 1
}


# -------------- SNS ---------------

resource "aws_sns_topic" "admin_topic" {
  name = "Admins"
}

resource "aws_sns_topic_subscription" "admin_target" {
  topic_arn = aws_sns_topic.admin_topic.arn
  protocol  = "email"
  endpoint  = var.ADMIN_EMAIL

}

# resource "aws_sns_topic_policy" "admin_topic_policy" {
#   arn    = aws_sns_topic.admin_topic.arn
#   policy = data.aws_iam_policy_document.topic_policy_document.json
# }

resource "aws_sns_topic" "failure_topic" {
  name = "Create-Account-Failures"
}

resource "aws_sns_topic_subscription" "failure_sqs_target" {
  topic_arn = aws_sns_topic.failure_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.failure_queue.arn
}

# resource "aws_sns_topic_policy" "topic_policy" {
#   arn    = aws_sns_topic.failure_topic.arn
#   policy = data.aws_iam_policy_document.topic_policy_document.json
# }

# -------------- SQS ---------------

data "aws_iam_policy_document" "failure_queue_policy_document" {
  statement {
    actions = ["sqs:*"]
    effect  = "Allow"
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }
    resources = ["arn:aws:sqs:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}"]
  }

  statement {
    actions = ["sqs:SendMessage"]
    effect  = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    resources = [aws_sqs_queue.failure_queue.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.failure_topic.arn]
    }
  }
}

resource "aws_sqs_queue" "failure_queue" {
  name                       = "Step-failure"
  visibility_timeout_seconds = "30"
  message_retention_seconds  = "345600"
  max_message_size           = "262144"
  delay_seconds              = "0"
  receive_wait_time_seconds  = "0"
}

resource "aws_sqs_queue_policy" "failure_queue_policy" {
  queue_url = aws_sqs_queue.failure_queue.id
  policy    = data.aws_iam_policy_document.failure_queue_policy_document.json
}


# ------------ State Machine -------------

data "template_file" "state_machine_definition" {
  template = file("./state.tpl")
  vars = {
    activate_account_function_arn = "${aws_lambda_function.activate_account.arn}",
    create_account_function_arn   = "${aws_lambda_function.create_account.arn}",
    admin_topic_arn = "${aws_sns_topic.admin_topic.arn}",
    failure_topic_arn = "${aws_sns_topic.failure_topic.arn}"
  }
}

data "aws_iam_policy_document" "sfn_assume_role_policy_document" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}


data "aws_iam_policy_document" "sfn_execution_policy_document" {

  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents","logs:*"]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions = [
      "lambda:InvokeFunction"
    ]
    effect    = "Allow"
    resources = [aws_lambda_function.create_account.arn, aws_lambda_function.activate_account.arn]
  }

  statement {
    actions = [
      "sns:Publish"
    ]
    effect    = "Allow"
    resources = [aws_sns_topic.admin_topic.arn, aws_sns_topic.failure_topic.arn]
  }

}

resource "aws_iam_policy" "sfn_execution_policy" {
  name   = "sfn-execution-policy"
  policy = data.aws_iam_policy_document.sfn_execution_policy_document.json
}

resource "aws_iam_role" "iam_for_sfn" {
  name                = "iam_for_sfn"
  assume_role_policy  = data.aws_iam_policy_document.sfn_assume_role_policy_document.json
  managed_policy_arns = [aws_iam_policy.sfn_execution_policy.arn]
}

resource "aws_cloudwatch_log_group" "sfn_log_group" {
  name              = "/aws/states/account-creation-state-machine"
  retention_in_days = 1
}

resource "aws_sfn_state_machine" "sfn_state_machine" {
  name     = "account-creation-state-machine"
  role_arn = aws_iam_role.iam_for_sfn.arn

  definition = data.template_file.state_machine_definition.rendered

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn_log_group.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tracing_configuration {
    enabled = true
  }

}

# resource "aws_lambda_permission" "allow_state_machine_to_invoke_create_account" {
#   statement_id  = "AllowExecutionFromStateMachine"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.create_account.function_name
#   principal     = "states.amazonaws.com"
#   source_arn    = aws_sfn_state_machine.sfn_state_machine.arn
# }

# resource "aws_lambda_permission" "allow_state_machine_to_invoke_activate_account" {
#   statement_id  = "AllowExecutionFromStateMachine"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.activate_account.function_name
#   principal     = "states.amazonaws.com"
#   source_arn    = aws_sfn_state_machine.sfn_state_machine.arn
# }
