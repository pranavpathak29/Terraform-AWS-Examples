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

data "aws_iam_policy_document" "lambda_assume_role_policy_document" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_execution_policy_document" {

  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      "${aws_secretsmanager_secret.rds_credentials.arn}"
    ]
  }


  statement {
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda_execution_policy" {
  name   = "lamdba-dynamodb-execution-policy"
  policy = data.aws_iam_policy_document.lambda_execution_policy_document.json
}

resource "aws_iam_role" "lambda_execution_role" {
  name                = "lambda-dynamodb-execution-role"
  assume_role_policy  = data.aws_iam_policy_document.lambda_assume_role_policy_document.json
  managed_policy_arns = [aws_iam_policy.lambda_execution_policy.arn]
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

resource "aws_secretsmanager_secret" "rds_credentials" {
  name = "rds-credentials"
}

resource "aws_secretsmanager_secret_version" "rds_credentials_version" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = "${var.AWS_RDS_USERNAME}"
    password = "${var.AWS_RDS_PASSWORD}"
    host     = "${aws_rds_cluster.rds_aurora.endpoint}"
    port     = "${aws_rds_cluster.rds_aurora.port}"
    database = "${var.AWS_RDS_DB_NAME}"
  })
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

resource "aws_lambda_function" "lambda" {
  filename         = var.SOURCE_FILE_NAME
  function_name    = var.LAMBDA_NAME
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = var.LAMBDA_HANDLER
  source_code_hash = filebase64sha256("${var.SOURCE_FILE_PATH}/${var.SOURCE_FILE_NAME}")
  runtime          = var.LAMBDA_RUN_TIME
  timeout          = 30
  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      SECRET_API_KEY = "${aws_secretsmanager_secret.rds_credentials.arn}"
      SECRET_REGION  = var.AWS_REGION
    }
  }
}

resource "aws_cloudwatch_log_group" "loggroup" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 14
}
