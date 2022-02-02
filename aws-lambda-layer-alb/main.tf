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
    actions   = ["lambda:GetAccountSettings", "s3:ListAllMyBuckets"]
    effect    = "Allow"
    resources = ["*"]
  }

  //To Enable VPC for Lambda
  /* statement {
    actions = [
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeInstances",
      "ec2:AttachNetworkInterface"
    ]
    effect    = "Allow"
    resources = ["*"]

  }*/

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
  name   = "lamdba-execution-policy"
  policy = data.aws_iam_policy_document.lambda_execution_policy_document.json
}

resource "aws_iam_role" "lambda_execution_role" {
  name                = "lambda-execution-role"
  assume_role_policy  = data.aws_iam_policy_document.lambda_assume_role_policy_document.json
  managed_policy_arns = [aws_iam_policy.lambda_execution_policy.arn]
}

resource "aws_lambda_layer_version" "lambda_layer" {
  filename            = var.LAYER_FILE_NAME
  layer_name          = var.LAYER_NAME
  source_code_hash    = filebase64sha256("${var.LAYER_FILE_PATH}/${var.LAYER_FILE_NAME}")
  compatible_runtimes = [var.LAMBDA_RUN_TIME]
}


resource "aws_lambda_function" "lambda" {
  filename         = var.SOURCE_FILE_NAME
  function_name    = var.LAMBDA_NAME
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = var.LAMBDA_HANDLER
  source_code_hash = filebase64sha256("${var.SOURCE_FILE_PATH}/${var.SOURCE_FILE_NAME}")
  runtime          = var.LAMBDA_RUN_TIME
  timeout          = 30
  
  //To enable lambda in vpc
  /*vpc_config {
    subnet_ids         = data.aws_subnet_ids.subnet.ids
    security_group_ids = [aws_security_group.sg_lamda_asg.id]
  }*/


  layers = [aws_lambda_layer_version.lambda_layer.arn]

  tracing_config {
    mode = "Active"
  }
}

resource "aws_cloudwatch_log_group" "loggroup" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 14
}

//To enable lambda in vpc
/*resource "aws_security_group" "sg_lamda_asg" {
  name        = "sg_lamda_asg"
  description = "role for lambda asg"
  vpc_id      = data.aws_vpc.main.id

  ingress = [{
    description      = "HTTP endpoint"
    from_port        = 80
    to_port          = 80
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
}*/

resource "aws_security_group" "sg_alb_asg" {
  name        = "sg_laalb_asg"
  description = "role for lambda asg"
  vpc_id      = data.aws_vpc.main.id

  ingress = [{
    description      = "HTTP endpoint"
    from_port        = 80
    to_port          = 80
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

resource "aws_lb" "lambda_load_balancer" {
  name               = "lambda-load-balancer"
  internal           = false
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.subnet.ids

  enable_cross_zone_load_balancing = true
  security_groups                  = [aws_security_group.sg_alb_asg.id]
  tags = {
    Name = "AWS-Lambda-Load-Balancer"
  }
}

resource "aws_lb_target_group" "primary" {
  name        = "lb-tg-primary"
  target_type = "lambda"
}

resource "aws_lb_listener" "lb_listiner_primary" {
  load_balancer_arn = aws_lb.lambda_load_balancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.primary.arn
  }
}

resource "aws_lambda_permission" "with_lb" {
  statement_id  = "AllowExecutionFromlb"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.primary.arn
}


resource "aws_lb_target_group_attachment" "alb_tg_attachment" {
  target_group_arn = aws_lb_target_group.primary.arn
  target_id        = aws_lambda_function.lambda.arn
  depends_on       = [aws_lambda_permission.with_lb]
}
