provider "aws" {
  region     = var.AWS_REGION
  secret_key = var.AWS_SECRET_KEY
  access_key = var.AWS_ACCESS_KEY
}

resource "aws_s3_bucket" "bucket" {
  bucket = var.AWS_S3_BUCKET_NAME
  acl    = "private"

  tags = {
    Name = var.AWS_S3_BUCKET_NAME
  }

  website {
    index_document = "index.html"
    error_document = "index.html"
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
    id                                     = "clean_rule"
    enabled                                = true
    abort_incomplete_multipart_upload_days = 5

    expiration {
      days = 30
    }
  }
}

data "aws_iam_policy_document" "allow_access_to_public" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      aws_s3_bucket.bucket.arn,
      "${aws_s3_bucket.bucket.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.allow_access_to_public.json
}

resource "aws_s3_bucket_object" "index_file" {
  bucket = aws_s3_bucket.bucket.id
  key = "index.html"
  source = "static/index.html"
  etag = filemd5("static/index.html")
}