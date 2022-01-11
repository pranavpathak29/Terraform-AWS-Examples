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

  statement {
    actions = ["sqs:SendMessage"]
    effect  = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    resources = [aws_sqs_queue.queue.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.my_topics.arn]
    }
  }
}

data "aws_iam_policy_document" "topic_policy_document" {
  statement {
    actions = [
      "SNS:Publish",
      "SNS:RemovePermission",
      "SNS:SetTopicAttributes",
      "SNS:DeleteTopic",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
      "SNS:AddPermission",
      "SNS:Subscribe"
    ]
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    resources = [aws_sns_topic.my_topics.arn]
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


resource "aws_sns_topic" "my_topics" {
  name = "my_topics"
}

resource "aws_sns_topic_subscription" "my_sqs_target" {
  topic_arn = aws_sns_topic.my_topics.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.queue.arn
}

resource "aws_sns_topic_policy" "topic_policy" {
  arn    = aws_sns_topic.my_topics.arn
  policy = data.aws_iam_policy_document.topic_policy_document.json
}
