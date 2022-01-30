terraform {
  backend "s3" {
    bucket               = "aws-terraform-stages"
    key                  = "aws-lambda"
    region               = "ap-south-1"
    workspace_key_prefix = "aws-sample"
  }
}
