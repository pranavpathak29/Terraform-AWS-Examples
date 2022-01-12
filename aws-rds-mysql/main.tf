provider "aws" {
  region     = var.AWS_REGION
  secret_key = var.AWS_SECRET_KEY
  access_key = var.AWS_ACCESS_KEY
}

data "aws_caller_identity" "current" {}

data "aws_vpc" "main" {
  id = var.VPC_ID
}

data "aws_subnet_ids" "subnet" {
  vpc_id = data.aws_vpc.main.id
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = data.aws_subnet_ids.subnet.ids

  tags = {
    Name = "RDS Subnet Group"
  }
}

resource "aws_security_group" "sg_rds_mysql" {
  name        = "rds-mysql"
  description = "Role for RDS MySQL"
  vpc_id      = data.aws_vpc.main.id
  ingress = [{
    description      = "MYSQL"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }]

  egress = [{
    description      = "Outbound rule"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }]
}

resource "aws_db_instance" "rds_mysql" {
  engine               = "mysql"
  engine_version = "8.0.27"
  identifier = var.AWS_RDS_IDENTIFIER
  username = var.AWS_RDS_USERNAME
  password = var.AWS_RDS_PASSWORD
  instance_class       = "db.t2.micro"
  allocated_storage = 10
  storage_type = "gp2"
  max_allocated_storage = 20
  multi_az = false
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  publicly_accessible = true
  vpc_security_group_ids = [aws_security_group.sg_rds_mysql.id]
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot = true
}