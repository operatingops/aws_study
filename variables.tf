variable "aws_region" {
}

variable "enabled" {
  default     = true
  description = "Turns EC2 instances and the NAT on and off."
}

variable "key_name" {
  description = "EC2 SSH key (not a local key)"
}

# terraform-null-label inputs
variable "namespace" {
  type    = string
  default = ""
}

variable "environment" {
  type    = string
  default = ""
}

variable "stage" {
  type    = string
  default = ""
}

variable "delimiter" {
  type    = string
  default = "-"
}

variable "attributes" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "additional_tag_map" {
  type    = map(string)
  default = {}
}

variable "context" {
  type = object({
    namespace           = string
    environment         = string
    stage               = string
    name                = string
    enabled             = bool
    delimiter           = string
    attributes          = list(string)
    label_order         = list(string)
    tags                = map(string)
    additional_tag_map  = map(string)
    regex_replace_chars = string
  })
  default = {
    namespace           = ""
    environment         = ""
    stage               = ""
    name                = ""
    enabled             = true
    delimiter           = ""
    attributes          = []
    label_order         = []
    tags                = {}
    additional_tag_map  = {}
    regex_replace_chars = ""
  }
}

variable "label_order" {
  type    = list(string)
  default = []
}

variable "regex_replace_chars" {
  type    = string
  default = "/[^a-zA-Z0-9-]/"
}
