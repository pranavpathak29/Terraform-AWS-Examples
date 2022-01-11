provider "aws" {
  region     = var.AWS_REGION
  secret_key = var.AWS_SECRET_KEY
  access_key = var.AWS_ACCESS_KEY
}

data "aws_caller_identity" "current" {}

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
