data "aws_ami" "ami" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn-ami-hvm*"]
  }
}

module "vpc_label" {
  source             = "git::https://github.com/cloudposse/terraform-null-label.git?ref=0.5.3"
  namespace          = "${var.namespace}"
  environment        = "${var.environment}"
  stage              = "${var.stage}"
  name               = "vpc"
  delimiter          = "${var.delimiter}"
  attributes         = "${var.attributes}"
  tags               = "${var.tags}"
  additional_tag_map = "${var.additional_tag_map}"
  context            = "${var.context}"
  label_order        = "${var.label_order}"
}

module "vpc" {
  name   = "${module.vpc_label.id}"
  tags   = "${module.vpc_label.tags}"
  source = "github.com/terraform-aws-modules/terraform-aws-vpc?ref=v1.46.0"

  azs                = ["${var.aws_region}a", "${var.aws_region}b"]
  cidr               = "10.0.0.0/22"
  enable_dns_support = "true"

  # So testa/b can install tools.
  enable_nat_gateway      = "${var.enabled}"
  single_nat_gateway      = "true"
  map_public_ip_on_launch = "false"
  private_subnets         = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets          = ["10.0.0.0/24"]
}

# The terraform-aws-vpc module gives the same ACL to all subnets. We create and
# assign new ones so you can test rules applied to individual subnets.
resource "aws_network_acl" "private_subnet_acl" {
  # Fails with length() because these are computed values.
  count      = "2"
  vpc_id     = "${module.vpc.vpc_id}"
  subnet_ids = ["${element(module.vpc.private_subnets, count.index)}"]
  tags       = "${module.vpc_label.tags}"

  # Allow SSH from bastion.
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.0.0.0/24"
    from_port  = 22
    to_port    = 22
  }

  # Return traffic goes out to whatever ephemeral port the source OS picked
  # when it sent the incoming packet. See this for the range:
  # http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_ACLs.html#VPC_ACLs_Ephemeral_Ports
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.0.0.0/24"
    from_port  = 32768
    to_port    = 61000
  }

  # Allow HTTP/S and FTP for yum so you can install stuff when the NAT is on.
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

  # Return traffic comes in to whatever ephemeral port the OS picked when it
  # sent the outgoing packet. See this for the range:
  # http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_ACLs.html#VPC_ACLs_Ephemeral_Ports
  ingress {
    protocol   = "tcp"
    rule_no    = 101
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 32768
    to_port    = 61000
  }

  depends_on = ["module.vpc"]
}

module "bastion_label" {
  source             = "git::https://github.com/cloudposse/terraform-null-label.git?ref=0.5.3"
  namespace          = "${var.namespace}"
  environment        = "${var.environment}"
  stage              = "${var.stage}"
  name               = "bastion"
  delimiter          = "${var.delimiter}"
  attributes         = "${var.attributes}"
  tags               = "${var.tags}"
  additional_tag_map = "${var.additional_tag_map}"
  context            = "${var.context}"
  label_order        = "${var.label_order}"
}

resource "aws_security_group" "bastion" {
  name        = "${module.bastion_label.id}"
  tags        = "${module.bastion_label.tags}"
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
    cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24"] # Private subnets.
  }
}

resource "aws_instance" "bastion" {
  count                       = "${var.enabled ? 1 : 0}"
  ami                         = "${data.aws_ami.ami.image_id}"
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = "${var.key_name}"
  subnet_id                   = "${module.vpc.public_subnets[0]}"
  vpc_security_group_ids      = ["${aws_security_group.bastion.id}"]

  tags = "${module.bastion_label.tags}"
}

module "testa_label" {
  source             = "git::https://github.com/cloudposse/terraform-null-label.git?ref=0.5.3"
  namespace          = "${var.namespace}"
  environment        = "${var.environment}"
  stage              = "${var.stage}"
  name               = "testa"
  delimiter          = "${var.delimiter}"
  attributes         = "${var.attributes}"
  tags               = "${var.tags}"
  additional_tag_map = "${var.additional_tag_map}"
  context            = "${var.context}"
  label_order        = "${var.label_order}"
}

resource "aws_security_group" "testa" {
  name        = "${module.testa_label.id}"
  tags        = "${module.testa_label.tags}"
  description = "For the testa host."
  vpc_id      = "${module.vpc.vpc_id}"

  # Allow SSH from the public subnet (where the bastion runs).
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/24"]
  }

  # Allow HTTP/S and FTP traffic for yum so you can install stuff when the NAT is on.
  egress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
  }

  egress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 443
    to_port     = 443
  }

  egress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 20
    to_port     = 21
  }
}

resource "aws_instance" "testa" {
  count                  = "${var.enabled ? 1 : 0}"
  ami                    = "${data.aws_ami.ami.image_id}"
  instance_type          = "t2.micro"
  key_name               = "${var.key_name}"
  subnet_id              = "${module.vpc.private_subnets[0]}"
  vpc_security_group_ids = ["${aws_security_group.testa.id}"]

  tags = "${module.testa_label.tags}"
}

module "testb_label" {
  source             = "git::https://github.com/cloudposse/terraform-null-label.git?ref=0.5.3"
  namespace          = "${var.namespace}"
  environment        = "${var.environment}"
  stage              = "${var.stage}"
  name               = "testb"
  delimiter          = "${var.delimiter}"
  attributes         = "${var.attributes}"
  tags               = "${var.tags}"
  additional_tag_map = "${var.additional_tag_map}"
  context            = "${var.context}"
  label_order        = "${var.label_order}"
}

resource "aws_security_group" "testb" {
  name        = "${module.testb_label.id}"
  tags        = "${module.testb_label.tags}"
  description = "For the testb host."
  vpc_id      = "${module.vpc.vpc_id}"

  # Allow SSH from the public subnet (where the bastion runs).
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/24"]
  }

  # Allow HTTP/S and FTP traffic for yum so you can install stuff when the NAT is on.
  egress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
  }

  egress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 443
    to_port     = 443
  }

  egress {
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 20
    to_port     = 21
  }
}

resource "aws_instance" "testb" {
  count                  = "${var.enabled ? 1 : 0}"
  ami                    = "${data.aws_ami.ami.image_id}"
  instance_type          = "t2.micro"
  key_name               = "${var.key_name}"
  subnet_id              = "${module.vpc.private_subnets[1]}"
  vpc_security_group_ids = ["${aws_security_group.testb.id}"]

  tags = "${module.testb_label.tags}"
}
