# About

A terraform module that deploys a nothing-out-of-box VPC for learning AWS networking (hands-on). The VPC and its resources only implement what's needed to make SSH work and to allow you to install system packages for testing. This way you can more easily see what rules/routes/etc. are really needed for traffic flows (because everything is disabled or blocked until you specifically enable it). This is primarily designed for you to run tests between the two private subnets.

![Network Diagram](diagram.png)

# User Guide

For example:

```
module "study" {
  source = "git::https://github.com/operatingops/aws_study.git?ref=master"

  aws_region = "us-west-2"
  enabled    = true
  key_name   = "adam"

  # terraform-null-label inputs
  namespace = "study"
  stage     = "dev-1"
}
```

If you get errors, wait a minute and retry applying. It may take a bit for newly created or deleted resources in AWS to sync through the backend.

To de-provision the EC2 instances and NAT Gateways, without deleting any of the network infrastructure, set:

```enabled = false```

This uses cloudposse's [terraform-null-label](https://github.com/cloudposse/terraform-null-label/tree/0.5.3) to generate resource names and tags, and it accepts the same variables.
