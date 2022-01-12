provider "aws" {
  region     = var.AWS_REGION
  secret_key = var.AWS_SECRET_KEY
  access_key = var.AWS_ACCESS_KEY
}

resource "aws_kinesis_stream" "test_stream" {
  name             = var.AWS_STREAM_NAME
  shard_count      = 1
  retention_period = 48

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }
}
