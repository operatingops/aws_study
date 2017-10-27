terraform {
  backend "s3" {
    key = "study"
  }
}

data "terraform_remote_state" "study" {
  backend = "s3"

  config {
    bucket = "${data.aws_caller_identity.current.account_id}-${var.aws_region}-terraform"
    key    = "study"
    region = "${var.aws_region}"
  }
}

data "aws_caller_identity" "current" {}

provider "aws" {
  region = "${var.aws_region}"
}

module "vpc" {
  name   = "aws-study-vpc"
  source = "github.com/terraform-aws-modules/terraform-aws-vpc?ref=v1.0.4"

  azs                     = ["${var.aws_region}a", "${var.aws_region}b"]
  cidr                    = "10.0.0.0/21"
  enable_dns_support      = "true"
  enable_nat_gateway      = "${var.enabled}" # So you can install networking tools.
  single_nat_gateway      = "true"
  map_public_ip_on_launch = "false"
  private_subnets         = ["10.0.0.0/24", "10.0.1.0/24"]
  public_subnets          = ["10.0.3.0/24"]
}

# The terraform-aws-vpc module gives the same ACL to all subnets, so we create and assign new ones.
resource "aws_network_acl" "private_subnet_acl" {
  count = "2" # Can't use length() on the VPC module's subnets because they're computed values.
  vpc_id = "${module.vpc.vpc_id}"
  subnet_ids = ["${element(module.vpc.private_subnets, count.index)}"]

  # Allow traffic within the VPC.
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "${module.vpc.vpc_cidr_block}"
    from_port  = 0
    to_port    = 0
  }
  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "${module.vpc.vpc_cidr_block}"
    from_port  = 0
    to_port    = 0
  }

  # Allow HTTP/S and FTP traffic for yum so you can install stuff when the NAT is on.
  egress {
    protocol   = "tcp"
    rule_no    = 101
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
  egress {
    protocol   = "tcp"
    rule_no    = 102
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  egress {
    protocol   = "tcp"
    rule_no    = 103
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 20
    to_port    = 21
  }
  ingress {
    protocol   = "tcp"
    rule_no    = 101
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    # Return traffic for all three comes in to whatever ephemeral port the OS
    # picked when it sent the outgoing packet. See this for the range:
    # http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_ACLs.html#VPC_ACLs_Ephemeral_Ports
    from_port  = 32768
    to_port    = 61000
  }
}

resource "aws_security_group" "bastion" {
  name        = "bastion"
  description = "Allow SSH from the public Internet."
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["${module.vpc.vpc_cidr_block}"]
  }
}

resource "aws_security_group" "ssh_internal" {
  name        = "ssh_internal"
  description = "Allow SSH from the VPC."
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["${module.vpc.vpc_cidr_block}"]
  }
}

resource "aws_security_group" "test1" {
  name        = "test1"
  description = "For the test1 host."
  vpc_id      = "${module.vpc.vpc_id}"

  # Allow HTTP/S and FTP traffic for yum so you can install stuff when the NAT is on.
  egress {
    protocol   = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port  = 80
    to_port    = 80
  }
  egress {
    protocol   = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port  = 443
    to_port    = 443
  }
  egress {
    protocol   = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port  = 20
    to_port    = 21
  }
}

resource "aws_security_group" "test2" {
  name        = "test2"
  description = "For the test2 host."
  vpc_id      = "${module.vpc.vpc_id}"

  # Allow HTTP/S and FTP traffic for yum so you can install stuff when the NAT is on.
  egress {
    protocol   = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port  = 80
    to_port    = 80
  }
  egress {
    protocol   = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port  = 443
    to_port    = 443
  }
  egress {
    protocol   = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port  = 20
    to_port    = 21
  }
}

data "aws_ami" "ami" {
  most_recent      = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn-ami-hvm*"]
  }
}

resource "aws_instance" "bastion" {
  count                       = "${var.enabled ? 1 : 0}"
  ami                         = "${data.aws_ami.ami.image_id}"
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = "adam"
  subnet_id                   = "${module.vpc.public_subnets[0]}"
  vpc_security_group_ids      = ["${aws_security_group.bastion.id}"]

  tags {
    Name = "bastion"
  }
}

resource "aws_instance" "test1" {
  count                  = "${var.enabled ? 1 : 0}"
  ami                    = "${data.aws_ami.ami.image_id}"
  instance_type          = "t2.micro"
  key_name               = "adam"
  subnet_id              = "${module.vpc.private_subnets[0]}"
  vpc_security_group_ids = ["${aws_security_group.ssh_internal.id}","${aws_security_group.test1.id}"]

  tags {
    Name = "test1"
  }
}

resource "aws_instance" "test2" {
  count                  = "${var.enabled ? 1 : 0}"
  ami                    = "${data.aws_ami.ami.image_id}"
  instance_type          = "t2.micro"
  key_name               = "adam"
  subnet_id              = "${module.vpc.private_subnets[1]}"
  vpc_security_group_ids = ["${aws_security_group.ssh_internal.id}","${aws_security_group.test2.id}"]

  tags {
    Name = "test2"
  }
}
