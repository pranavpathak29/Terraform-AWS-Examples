terraform {
  backend "s3" {
    bucket               = "aws-terraform-stages"
    key                  = "aws-api-gateway-lamda"
    region               = "ap-south-1"
    workspace_key_prefix = "aws-sample"
  }
}
