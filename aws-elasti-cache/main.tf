provider "aws" {
  region     = var.AWS_REGION
  secret_key = var.AWS_SECRET_KEY
  access_key = var.AWS_ACCESS_KEY
}

data "aws_vpc" "main" {
  id = var.VPC_ID
}

data "aws_subnet_ids" "subnet" {
  vpc_id = data.aws_vpc.main.id
}

resource "aws_elasticache_subnet_group" "elasticache_subnet_group" {
  name       = "elasticache-subnet-group"
  subnet_ids = data.aws_subnet_ids.subnet.ids

  tags = {
    Name = "Elasti Cache Subnet Group"
  }
}

resource "aws_elasticache_cluster" "elasticache_cluster" {
  cluster_id           = var.AWS_CACHE_NAME
  engine               = "redis"
  node_type            = "cache.t2.micro"
  port                 = 6379
  engine_version       = "6.x"
  parameter_group_name = "default.redis6.x"
  num_cache_nodes = 1
  subnet_group_name    = aws_elasticache_subnet_group.elasticache_subnet_group.name
}
