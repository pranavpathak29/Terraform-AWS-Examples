terraform {
  backend "s3" {
    bucket               = "aws-terraform-stages"
    key                  = "aws-cloud-front-s3"
    region               = "ap-south-1"
    workspace_key_prefix = "aws-sample"
  }
}
