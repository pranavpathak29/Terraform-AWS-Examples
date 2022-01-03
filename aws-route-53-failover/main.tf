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

resource "aws_security_group" "sg_aws_instance1" {
  name        = "sg_aws_instance1"
  description = "role for instance1"
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

resource "aws_security_group" "sg_aws_instance2" {
  name        = "sg_aws_instance2"
  description = "role for instance2"
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
  vpc_security_group_ids = ["${aws_security_group.sg_aws_instance1.id}"]

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

resource "aws_instance" "instance2" {
  # get Amazon Linux 2 AMI
  ami                    = data.aws_ami.amazon-ec2.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.sg_aws_instance2.id}"]

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

resource "aws_route53_health_check" "hc_primary_instance1" {
  ip_address              = "${aws_instance.instance1.public_ip}"
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "3"
  request_interval  = "10"

  tags = {
    Name = "hc_primary_instance1"
  }
}

resource "aws_route53_record" "failover_instance1" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "failover.${data.aws_route53_zone.zone.name}"
  type    = "A"
  ttl     = "30"
  records = [aws_instance.instance1.public_ip]

  failover_routing_policy{
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.hc_primary_instance1.id

  set_identifier = "primary"
}



resource "aws_route53_health_check" "hc_primary_instance2" {
  ip_address              = "${aws_instance.instance2.public_ip}"
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "3"
  request_interval  = "10"

  tags = {
    Name = "hc_primary_instance2"
  }
}

resource "aws_route53_record" "failover_instance2" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "failover.${data.aws_route53_zone.zone.name}"
  type    = "A"
  ttl     = "30"
  records = [aws_instance.instance2.public_ip]

  failover_routing_policy{
    type = "SECONDARY"
  }

  health_check_id = aws_route53_health_check.hc_primary_instance2.id

  set_identifier = "secondary"
}
