terraform {
  backend "s3" {
    # acl                  = "bucket-owner-full-controll"
    bucket               = "aws-terraform-stages"
    key                  = "aws-ec2-simple"
    region               = "ap-south-1"
    workspace_key_prefix = "aws-sample"
  }
}
