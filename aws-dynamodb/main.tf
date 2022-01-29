provider "aws" {
  region     = var.AWS_REGION
  secret_key = var.AWS_SECRET_KEY
  access_key = var.AWS_ACCESS_KEY
}

data "aws_caller_identity" "current" {}

resource "aws_dynamodb_table" "dynamodb_table" {
  name           = var.TABLE_NAME
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "user_id"
  range_key      = "game_ts"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "game_ts"
    type = "S"
  }

  attribute {
    name = "game_id"
    type = "S"
  }

  local_secondary_index{
    name = "game_index"
    range_key = "game_id"
    projection_type = "ALL"
  }

  tags = {
    Name        = var.TABLE_NAME
    Environment = "test"
  }

}