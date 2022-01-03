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

data "aws_key_pair" "key_pair" {
  key_pair_id = var.KEY_PAIR_ID
}

resource "aws_security_group" "sg_aws_ec2_application_load_balancer_asg" {
  name        = "sg_aws_ec2_application_load_balancer_asg"
  description = "role for ec2"
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

resource "aws_security_group" "sg_aws_ec2_asg" {
  name        = "sg_aws_ec2_asg"
  description = "role for ec2"
  vpc_id      = data.aws_vpc.main.id

  ingress = [{
    description      = "HTTP endpoint"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = []
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = [aws_security_group.sg_aws_ec2_application_load_balancer_asg.id]
    self             = false

  },{
    description      = "SSH endpoint"
    from_port        = 22
    to_port          = 22
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


data "aws_ami" "amazon_ec2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }

  owners = ["amazon"] # Canonical
}

resource "aws_lb" "ec2_application_load_balancer" {
  name               = "ec2-application-load-balancer"
  internal           = false
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.subnet.ids

  enable_cross_zone_load_balancing = true
  security_groups                  = [aws_security_group.sg_aws_ec2_application_load_balancer_asg.id]
  tags = {
    Name = "AWS-EC2-Application-Load-Balancer"
  }
}

resource "aws_lb_target_group" "primary" {
  name     = "lb-tg-primary"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.main.id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    path                = "/"
    interval            = 30
    protocol            = "HTTP"
  }
}


resource "aws_lb_listener" "lb_listiner_primary" {
  load_balancer_arn = aws_lb.ec2_application_load_balancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.primary.arn
  }
}

resource "aws_launch_configuration" "asg_lc" {
  name          = "web_config"
  image_id      = data.aws_ami.amazon_ec2.image_id
  instance_type = "t2.micro"

  lifecycle {
    create_before_destroy = true
  }

  key_name        = data.aws_key_pair.key_pair.key_name
  security_groups = ["${aws_security_group.sg_aws_ec2_asg.id}"]

  user_data_base64 = filebase64("templates/ec2-user-data.sh")

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 8
    delete_on_termination = true
  }

}


resource "aws_autoscaling_group" "asg" {
  depends_on           = [aws_launch_configuration.asg_lc]
  vpc_zone_identifier  = data.aws_subnet_ids.subnet.ids
  desired_capacity     = 1
  max_size             = 4
  min_size             = 1
  health_check_type    = "ELB"
  force_delete         = true
  launch_configuration = aws_launch_configuration.asg_lc.id
  target_group_arns    = [aws_lb_target_group.primary.arn]

}

resource "aws_autoscaling_policy" "asg_policy" {
  name        = "asg-policy"
  policy_type = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 40.0
  }
  autoscaling_group_name = aws_autoscaling_group.asg.name
}
