terraform {
  backend "s3" {
    bucket               = "aws-terraform-stages"
    key                  = "aws-kinesis-delivery-stream"
    region               = "ap-south-1"
    workspace_key_prefix = "aws-sample"
  }
}
