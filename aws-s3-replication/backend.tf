terraform {
  backend "s3" {
    bucket               = "aws-terraform-stages"
    key                  = "aws-s3-replication"
    region               = "ap-south-1"
    workspace_key_prefix = "aws-sample"
  }
}
