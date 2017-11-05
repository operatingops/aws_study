variable "aws_region" {}

variable "enabled" {
  default     = true
  description = "Turns EC2 instances and the NAT on and off."
}

variable "key_name" {}
variable "state_bucket" {}
