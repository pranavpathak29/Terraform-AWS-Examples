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

resource "aws_security_group" "sg_rds_aurora" {
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

resource "aws_rds_cluster" "rds_aurora" {
  engine             = "aurora-mysql"
  engine_mode        = "provisioned"
  engine_version     = "8.0.mysql_aurora.3.01.0"
  cluster_identifier = var.AWS_RDS_IDENTIFIER
  database_name      = var.AWS_RDS_DB_NAME
  master_username    = var.AWS_RDS_USERNAME
  master_password    = var.AWS_RDS_PASSWORD

  # multi_az = false
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  # publicly_accessible = true
  vpc_security_group_ids          = [aws_security_group.sg_rds_aurora.id]
  port                            = "3306"
  db_cluster_parameter_group_name = "default.aurora-mysql8.0"
  skip_final_snapshot             = true
}

resource "aws_rds_cluster_instance" "rds_aurora_instances" {
  count               = 1
  identifier          = "${var.AWS_RDS_IDENTIFIER}-${count.index}"
  cluster_identifier  = aws_rds_cluster.rds_aurora.id
  instance_class      = "db.t3.medium"
  engine              = aws_rds_cluster.rds_aurora.engine
  engine_version      = aws_rds_cluster.rds_aurora.engine_version
  publicly_accessible = true
}
