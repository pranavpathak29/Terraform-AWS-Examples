provider "aws" {
  region     = var.AWS_REGION
  secret_key = var.AWS_SECRET_KEY
  access_key = var.AWS_ACCESS_KEY
}

data "aws_iam_policy_document" "delivery_stream_policy_document" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
    effect = "Allow"
  }
}

data "aws_iam_policy_document" "data_delivery_stream_policy_document" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
    effect = "Allow"
  }
}

data "aws_iam_policy_document" "data_stream_policy_document" {
  statement {
    actions = [
      "kinesis:PutRecord",
      "kinesis:DescribeStreamSummary",
      "kinesis:PutRecords",
      "kinesis:GetShardIterator",
      "kinesis:GetRecords",
      "kinesis:DescribeStream"
    ]
    effect    = "Allow"
    resources = [aws_kinesis_stream.data_stream.arn]
  }
}

data "aws_iam_policy_document" "data_s3_policy_document" {
  statement {
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject"
    ]
    effect = "Allow"
    resources = [
      aws_s3_bucket.bucket.arn,
      "${aws_s3_bucket.bucket.arn}/*",
    ]
  }
}

resource "aws_iam_policy" "data_stream_policy" {
  name   = "data_stream_policy"
  policy = data.aws_iam_policy_document.data_stream_policy_document.json
}

resource "aws_iam_policy" "data_s3_policy" {
  name   = "data_s3_policy"
  policy = data.aws_iam_policy_document.data_s3_policy_document.json
}

resource "aws_iam_role" "delivery_stream_role" {
  name                = "delivery_stream_role"
  assume_role_policy  = data.aws_iam_policy_document.data_delivery_stream_policy_document.json
  managed_policy_arns = [aws_iam_policy.data_stream_policy.arn, aws_iam_policy.data_s3_policy.arn]
}

resource "aws_s3_bucket" "bucket" {
  bucket        = var.AWS_S3_BUCKET_NAME
  acl           = "private"
  force_destroy = true
}

resource "aws_kinesis_stream" "data_stream" {
  name             = var.AWS_DATA_STREAM_NAME
  shard_count      = 1
  retention_period = 48

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }
}

resource "aws_kinesis_firehose_delivery_stream" "delivery_stream" {
  name        = var.AWS_DELIVERY_STREAM_NAME
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.data_stream.arn
    role_arn           = aws_iam_role.delivery_stream_role.arn
  }

  extended_s3_configuration {
    bucket_arn = aws_s3_bucket.bucket.arn
    role_arn   = aws_iam_role.delivery_stream_role.arn
  }
}
