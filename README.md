# About

Provisions a small VPC with test instances you can use for practicing AWS networking features. The VPC and its resources are limited to just what's needed to make SSH work and to allow you to install system packages for testing. This way you can more easily see what rules/routes/etc. are really needed for traffic flows. This is primarily designed for you to run tests between the two private subnets.

![Network Diagram](diagram.png)

# User Guide

1. Install [terraform](https://www.terraform.io).
1. [Configure](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html) the AWS CLI.
1. [Create or upload](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) an EC2 SSH key pair.
1. `source setup.sh <AWS CLI profile> <EC2 SSH key pair name>`.
1. `cd terraform`
1. `terraform get`
1. `terraform init -backend-config=.backend_config`
1. `terraform plan`
1. `terraform apply`

If you get errors, wait a minute and retry applying. It may take a bit for newly created or deleted resources in AWS to sync through the backend.

To de-provision the EC2 instances and NAT Gateways, without deleting any of the network infrastructure:
1. `export TF_VAR_enabled='false'`
2. `terraform apply`.
