terraform {
  backend "s3" {
    bucket               = "aws-terraform-stages"
    key                  = "aws-ec2-application-load-balancer-asg"
    region               = "ap-south-1"
    workspace_key_prefix = "aws-sample"
  }
}
