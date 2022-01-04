terraform {
  backend "s3" {
    bucket               = "aws-terraform-stages"
    key                  = "aws-s3-static-web-hosting"
    region               = "ap-south-1"
    workspace_key_prefix = "aws-sample"
  }
}
