terraform {
  backend "s3" {
    bucket               = "aws-terraform-stages"
    key                  = "aws-route-53-failover"
    region               = "ap-south-1"
    workspace_key_prefix = "aws-sample"
  }
}
