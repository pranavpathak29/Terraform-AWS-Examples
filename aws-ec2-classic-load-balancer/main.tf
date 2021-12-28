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


data "template_file" "user_data" {
  template = file("templates/ec2-user-data.tpl")
}

resource "aws_security_group" "sg_aws_ec2_classic_load_balancer" {
  name        = "sg_aws_ec2_classic_load_balancer"
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

resource "aws_security_group" "sg_aws_ec2" {
  name        = "sg_aws_ec2"
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
    security_groups  = [aws_security_group.sg_aws_ec2_classic_load_balancer.id]
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


resource "aws_instance" "instance_1" {
  # get Amazon Linux 2 AMI
  ami                    = data.aws_ami.amazon_ec2.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.sg_aws_ec2.id}"]
  key_name               = data.aws_key_pair.key_pair.key_name

  user_data = data.template_file.user_data.rendered

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 8
    delete_on_termination = true
  }

  tags = {
    Name = "AWS-EC2-Instance-1"
  }
}

resource "aws_instance" "instance_2" {
  # get Amazon Linux 2 AMI
  ami                    = data.aws_ami.amazon_ec2.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.sg_aws_ec2.id}"]
  key_name               = data.aws_key_pair.key_pair.key_name

  user_data = data.template_file.user_data.rendered

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 8
    delete_on_termination = true
  }

  tags = {
    Name = "AWS-EC2-Instance-2"
  }
}

resource "aws_instance" "instance_3" {
  # get Amazon Linux 2 AMI
  ami                    = data.aws_ami.amazon_ec2.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.sg_aws_ec2.id}"]
  key_name               = data.aws_key_pair.key_pair.key_name

  user_data = data.template_file.user_data.rendered

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 8
    delete_on_termination = true
  }

  tags = {
    Name = "AWS-EC2-Instance-3"
  }
}

resource "aws_elb" "ec2_classic_load_balancer"{
  name               = "ec2-classic-load-balancer"
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

  instances                   = [aws_instance.instance_1.id, aws_instance.instance_2.id, aws_instance.instance_3.id]

  cross_zone_load_balancing   = true
  security_groups = [aws_security_group.sg_aws_ec2_classic_load_balancer.id]
  tags = {
    Name = "AWS-EC2-Classic-Load-Balancer"
  }
}