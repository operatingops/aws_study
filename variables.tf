variable "aws_region" {}

variable "enabled" {
  default     = true
  description = "Turns EC2 instances and the NAT on and off."
}

variable "key_name" {
  description = "EC2 SSH key (not a local key)"
}

# terraform-null-label inputs
variable "namespace" {
  type    = "string"
  default = ""
}

variable "environment" {
  type    = "string"
  default = ""
}

variable "stage" {
  type    = "string"
  default = ""
}

variable "delimiter" {
  type    = "string"
  default = "-"
}

variable "attributes" {
  type    = "list"
  default = []
}

variable "tags" {
  type    = "map"
  default = {}
}

variable "additional_tag_map" {
  type    = "map"
  default = {}
}

variable "context" {
  type    = "map"
  default = {}
}

variable "label_order" {
  type    = "list"
  default = []
}
