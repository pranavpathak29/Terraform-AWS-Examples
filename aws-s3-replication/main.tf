provider "aws" {
  region     = var.AWS_REGION
  secret_key = var.AWS_SECRET_KEY
  access_key = var.AWS_ACCESS_KEY
}

provider "aws" {
  alias      = "replica_region"
  region     = var.AWS_REPLICA_REGION
  secret_key = var.AWS_SECRET_KEY
  access_key = var.AWS_ACCESS_KEY
}

resource "aws_s3_bucket" "destination" {
  bucket = var.AWS_S3_REPLICA_BUCKET_NAME

  tags = {
    Name = var.AWS_S3_REPLICA_BUCKET_NAME
  }

  versioning {
    enabled = true
  }
}

data "aws_iam_policy_document" "s3_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "s3_replica_policy_doc" {
  statement {
    actions   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags", "s3:ObjectOwnerOverrideToBucketOwner"]
    effect    = "Allow"
    resources = ["${aws_s3_bucket.destination.arn}/*", "${aws_s3_bucket.soruce.arn}/*"]
  }

  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetReplicationConfiguration",
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
      "s3:GetObjectRetention",
      "s3:GetObjectLegalHold"
    ]
    effect    = "Allow"
    resources = [aws_s3_bucket.destination.arn, "${aws_s3_bucket.destination.arn}/*", aws_s3_bucket.soruce.arn, "${aws_s3_bucket.soruce.arn}/*"]
  }
}

resource "aws_iam_role" "s3_assume_role_replica" {
  name               = "s3_assume_role_replica"
  assume_role_policy = data.aws_iam_policy_document.s3_assume_role_policy.json
}

resource "aws_iam_role_policy" "s3_replica_policy" {
  name = "s3_replica_policy"
  role = aws_iam_role.s3_assume_role_replica.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = data.aws_iam_policy_document.s3_replica_policy_doc.json
}


resource "aws_s3_bucket" "soruce" {
  bucket = var.AWS_S3_BUCKET_NAME
  acl    = "private"
  # TODO: need to fix as different region is taking much time and so aborted in between
  # provider = aws.replica_region 
  # region = var.AWS_REPLICA_REGION

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

  lifecycle {
    ignore_changes = [
      replication_configuration
    ]
  }

  replication_configuration {
    role = aws_iam_role.s3_assume_role_replica.arn

    rules {
      id     = "replication"
      status = "Enabled"

      filter {
        prefix = ""
      }

      delete_marker_replication_status = "Enabled"

      destination {
        bucket        = aws_s3_bucket.destination.arn
        storage_class = "STANDARD"

        replication_time {
          status  = "Enabled"
          minutes = 15
        }

        metrics {
          status  = "Enabled"
        }
      }
    }
  }
}