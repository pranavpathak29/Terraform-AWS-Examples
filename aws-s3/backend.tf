terraform {
  backend "s3" {
    bucket               = "aws-terraform-stages"
    key                  = "aws-s3"
    region               = "ap-south-1"
    workspace_key_prefix = "aws-sample"
  }
}
