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


data "template_file" "user_data_primary" {
  template = file("templates/ec2-user-data.tpl")
  vars = {
    application = "Primary"
  }
}

data "template_file" "user_data_secondary" {
  template = file("templates/ec2-user-data.tpl")
  vars = {
    application = "Secondary"
  }
}

resource "aws_security_group" "sg_aws_ec2_application_load_balancer" {
  name        = "sg_aws_ec2_application_load_balancer"
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
    description      = "HTTP endpoint"
    from_port        = 8080
    to_port          = 8080
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
    security_groups  = [aws_security_group.sg_aws_ec2_application_load_balancer.id]
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

  user_data = data.template_file.user_data_primary.rendered

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

  user_data = data.template_file.user_data_primary.rendered

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

  user_data = data.template_file.user_data_secondary.rendered

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 8
    delete_on_termination = true
  }

  tags = {
    Name = "AWS-EC2-Instance-3"
  }
}

resource "aws_instance" "instance_4" {
  # get Amazon Linux 2 AMI
  ami                    = data.aws_ami.amazon_ec2.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.sg_aws_ec2.id}"]
  key_name               = data.aws_key_pair.key_pair.key_name

  user_data = data.template_file.user_data_secondary.rendered

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 8
    delete_on_termination = true
  }

  tags = {
    Name = "AWS-EC2-Instance-4"
  }
}

resource "aws_lb" "ec2_application_load_balancer" {
  name               = "ec2-application-load-balancer"
  internal           = false
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.subnet.ids

  enable_cross_zone_load_balancing = true
  security_groups                  = [aws_security_group.sg_aws_ec2_application_load_balancer.id]
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

resource "aws_lb_target_group_attachment" "primary_1" {
  target_group_arn = aws_lb_target_group.primary.arn
  target_id        = aws_instance.instance_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "primary_2" {
  target_group_arn = aws_lb_target_group.primary.arn
  target_id        = aws_instance.instance_2.id
  port             = 80
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

resource "aws_lb_target_group" "secondary" {
  name     = "lb-tg-secondary"
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

resource "aws_lb_target_group_attachment" "secondary_1" {
  target_group_arn = aws_lb_target_group.secondary.arn
  target_id        = aws_instance.instance_3.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "secondary_2" {
  target_group_arn = aws_lb_target_group.secondary.arn
  target_id        = aws_instance.instance_4.id
  port             = 80
}

resource "aws_lb_listener" "lb_listiner_secondary" {
  load_balancer_arn = aws_lb.ec2_application_load_balancer.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.secondary.arn
  }
}
