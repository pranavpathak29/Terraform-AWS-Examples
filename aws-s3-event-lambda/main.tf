provider "aws" {
  region     = var.AWS_REGION
  secret_key = var.AWS_SECRET_KEY
  access_key = var.AWS_ACCESS_KEY
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "bucket" {
  bucket        = var.AWS_S3_BUCKET_NAME
  acl           = "private"
  force_destroy = true

  tags = {
    Name = var.AWS_S3_BUCKET_NAME
  }

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
      # bucket_key_enabled = false # works with aws:kms only to select aws/s3 key or kms one
    }
  }

  lifecycle_rule {
    id                                     = "version_bucket"
    enabled                                = true
    abort_incomplete_multipart_upload_days = 5

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 65
      storage_class = "ONEZONE_IA"
    }

    expiration {
      days                         = 75
      expired_object_delete_marker = true
    }


    noncurrent_version_transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    noncurrent_version_transition {
      days          = 65
      storage_class = "ONEZONE_IA"
    }

    noncurrent_version_expiration {
      days = 70
    }

  }
}

data "aws_iam_policy_document" "s3_lambda_assume_role_policy_document" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "s3_lambda_execution_policy_document" {

  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    effect    = "Allow"
    resources = ["*"]
  }

}

resource "aws_iam_policy" "s3_lambda_execution_policy" {
  name   = "s3-lamdba-execution-policy"
  policy = data.aws_iam_policy_document.s3_lambda_execution_policy_document.json
}

resource "aws_iam_role" "s3_lambda_execution_role" {
  name                = "s3-lambda-execution-role"
  assume_role_policy  = data.aws_iam_policy_document.s3_lambda_assume_role_policy_document.json
  managed_policy_arns = [aws_iam_policy.s3_lambda_execution_policy.arn]
}

resource "aws_lambda_function" "lambda" {
  filename         = var.SOURCE_FILE_NAME
  function_name    = var.LAMBDA_NAME
  role             = aws_iam_role.s3_lambda_execution_role.arn
  handler          = var.LAMBDA_HANDLER
  source_code_hash = filebase64sha256("${var.SOURCE_FILE_PATH}/${var.SOURCE_FILE_NAME}")
  runtime          = var.LAMBDA_RUN_TIME

}

resource "aws_lambda_permission" "with_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.bucket.arn
}

resource "aws_cloudwatch_log_group" "loggroup" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 14
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda.arn
    events              = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }
}
