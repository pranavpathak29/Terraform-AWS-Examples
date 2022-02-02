variable "AWS_REGION" { default = "ap-south-1"}
variable "AWS_SECRET_KEY" {}
variable "AWS_ACCESS_KEY" {}
variable "LAMBDA_NAME" {}
variable "LAMBDA_RUN_TIME" {}
variable "LAMBDA_HANDLER" {}
variable "SOURCE_FILE_NAME" {}
variable "SOURCE_FILE_PATH" {}
variable "LAYER_NAME" { default = "custom-layer"}
variable "LAYER_FILE_NAME" {}
variable "LAYER_FILE_PATH" {}
variable "VPC_ID" {}