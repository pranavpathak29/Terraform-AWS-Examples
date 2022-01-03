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

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default{
        sse_algorithm = "AES256"
      }
      # bucket_key_enabled = false # works with aws:kms only to select aws/s3 key or kms one
    }
  }

  lifecycle_rule {
    id = "version_bucket"
    enabled  = true
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
      days = 75
      expired_object_delete_marker = true
    }


    noncurrent_version_transition{
      days = 30
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
