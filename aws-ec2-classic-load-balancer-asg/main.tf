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


resource "aws_security_group" "sg_aws_ec2_classic_load_balancer_asg" {
  name        = "sg_aws_ec2_classic_load_balancer_asg"
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
    security_groups  = [aws_security_group.sg_aws_ec2_classic_load_balancer_asg.id]
    self             = false
  }, {
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

resource "aws_launch_template" "asg_lt" {
  name_prefix            = "asg-instance"
  image_id               = data.aws_ami.amazon_ec2.image_id
  instance_type          = "t2.micro"
  key_name               = data.aws_key_pair.key_pair.key_name
  vpc_security_group_ids = ["${aws_security_group.sg_aws_ec2_asg.id}"]
  user_data              = filebase64("templates/ec2-user-data.sh")

  # block_device_mappings {
  #   device_name = "/dev/sda1"
  #   ebs {
  #     volume_type           = "gp2"
  #     volume_size           = 8
  #     delete_on_termination = true
  #   }
  # }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "AWS-ASG-Instance"
    }
  }

  monitoring {
    enabled = true
  }

}

resource "aws_autoscaling_group" "asg" {
  vpc_zone_identifier = data.aws_subnet_ids.subnet.ids
  desired_capacity    = 2
  max_size            = 4
  min_size            = 1

  launch_template {
    id      = aws_launch_template.asg_lt.id
    version = "$Latest"
  }

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

resource "aws_elb" "ec2_classic_load_balancer" {
  name    = "ec2-classic-load-balancer"
  subnets = data.aws_subnet_ids.subnet.ids
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  cross_zone_load_balancing = true
  security_groups           = [aws_security_group.sg_aws_ec2_classic_load_balancer_asg.id]
  tags = {
    Name = "AWS-EC2-Classic-Load-Balancer"
  }
}

resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  autoscaling_group_name = aws_autoscaling_group.asg.id
  elb                    = aws_elb.ec2_classic_load_balancer.id
}
