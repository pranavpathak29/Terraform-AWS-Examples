provider "aws" {
  region     = var.AWS_REGION
  secret_key = var.AWS_SECRET_KEY
  access_key = var.AWS_ACCESS_KEY
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "bucket" {
  bucket = var.AWS_S3_BUCKET_NAME
  acl    = "private"

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

data "aws_iam_policy_document" "queue_policy_document" {
 
  statement {
    actions = ["sqs:*"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.bucket.arn]
    }
    resources = [aws_sqs_queue.queue.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sqs_queue" "queue" {
  name                       = "my-queue"
  visibility_timeout_seconds = "30"
  message_retention_seconds  = "345600"
  max_message_size           = "262144"
  delay_seconds              = "0"
  receive_wait_time_seconds  = "0"
}

resource "aws_sqs_queue_policy" "queue_policy" {
  queue_url = aws_sqs_queue.queue.id
  policy    = data.aws_iam_policy_document.queue_policy_document.json
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.bucket.id

  queue {
    queue_arn = aws_sqs_queue.queue.arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }
}