# About

Provisions a small VPC with test instances you can use for practicing AWS networking features. The VPC and its resources are limited to just what's needed to make SSH work and to allow you to install system packages for testing. This way you can more easily see what rules/routes/etc. are really needed for traffic flows.

# User Guide

1. Install [terraform](https://www.terraform.io).
1. [Configure](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html) the AWS CLI.
1. `source setup.sh <AWS CLI profile>` (profile defaults to `default`).
1. `cd terraform`
1. `terraform get`
1. `terraform init -backend-config=.backend_config`
1. `terraform plan`
1. `terraform apply`

To de-provision the EC2 instances and NAT Gateways, without deleting any of the network infrastructure, `export TF_VAR_enabled='false'` and `terraform apply`.
