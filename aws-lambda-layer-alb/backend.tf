terraform {
  backend "s3" {
    bucket               = "aws-terraform-stages"
    key                  = "aws-lambda-layer-alb"
    region               = "ap-south-1"
    workspace_key_prefix = "aws-sample"
  }
}
