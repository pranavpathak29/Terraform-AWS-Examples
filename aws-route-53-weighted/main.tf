provider "aws" {
  region     = var.AWS_REGION
  secret_key = var.AWS_SECRET_KEY
  access_key = var.AWS_ACCESS_KEY
}

data "aws_vpc" "main" {
  id = var.VPC_ID
}

data "aws_route53_zone" "zone" {
  zone_id = var.ROUTE_53_ZONE_ID
}

data "template_file" "user_data" {
  template = file("templates/ec2-user-data.tpl")
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
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    prefix_list_ids  = []
    security_groups  = []
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


data "aws_ami" "amazon-ec2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }

  owners = ["amazon"] # Canonical
}


resource "aws_instance" "instance1" {
  # get Amazon Linux 2 AMI
  ami                    = data.aws_ami.amazon-ec2.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.sg_aws_ec2.id}"]

  user_data = data.template_file.user_data.rendered

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 8
    delete_on_termination = true
  }

  tags = {
    Name = "AWS-EC2"
  }
}

resource "aws_instance" "instance2" {
  # get Amazon Linux 2 AMI
  ami                    = data.aws_ami.amazon-ec2.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.sg_aws_ec2.id}"]

  user_data = data.template_file.user_data.rendered

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 8
    delete_on_termination = true
  }

  tags = {
    Name = "AWS-EC2"
  }
}

resource "aws_route53_record" "instance1" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "weighted.${data.aws_route53_zone.zone.name}"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.instance1.public_ip]

  weighted_routing_policy {
    weight = 50
  }
  set_identifier = "instance1"
}

resource "aws_route53_record" "instance2" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "weighted.${data.aws_route53_zone.zone.name}"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.instance2.public_ip]

  weighted_routing_policy {
    weight = 50
  }
  set_identifier = "instance2"
}


