variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "environment" {
  type = string
}

variable "cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "project" {
  type = string
}

variable "domain" {
  type = string
}

variable "app_version" {
  type = string
}

variable "account_id" {
  type = string
}
