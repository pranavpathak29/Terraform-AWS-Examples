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
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchWriteItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem"
    ]
    effect    = "Allow"
    resources = [aws_dynamodb_table.dynamodb_table.arn]
  }

  statement {
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda_execution_policy" {
  name   = "lamdba-dynamodb-execution-policy"
  policy = data.aws_iam_policy_document.lambda_execution_policy_document.json
}

resource "aws_iam_role" "lambda_execution_role" {
  name                = "lambda-dynamodb-execution-role"
  assume_role_policy  = data.aws_iam_policy_document.lambda_assume_role_policy_document.json
  managed_policy_arns = [aws_iam_policy.lambda_execution_policy.arn]
}


resource "aws_dynamodb_table" "dynamodb_table" {
  name           = var.TABLE_NAME
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "org_id"
  range_key      = "emp_id"

  attribute {
    name = "org_id"
    type = "S"
  }

  attribute {
    name = "emp_id"
    type = "S"
  }

  tags = {
    Name = var.TABLE_NAME
  }

}

resource "aws_lambda_function" "lambda" {
  filename         = var.SOURCE_FILE_NAME
  function_name    = var.LAMBDA_NAME
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = var.LAMBDA_HANDLER
  source_code_hash = filebase64sha256("${var.SOURCE_FILE_PATH}/${var.SOURCE_FILE_NAME}")
  runtime          = var.LAMBDA_RUN_TIME

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      TableName = var.TABLE_NAME
    }
  }
}

resource "aws_cloudwatch_log_group" "loggroup" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 14
}
