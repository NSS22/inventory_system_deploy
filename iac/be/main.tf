
terraform {
  backend "s3" {
    region = "eu-west-1" # TODO Move this to pipeline
    key    = "inventory_system.tfstate"
  }
  required_providers {
    aws = {
      source  = "registry.terraform.io/hashicorp/aws"
      version = ">= 5.68.0"
    }
    random = {
      source  = "registry.terraform.io/hashicorp/random"
      version = "~> 3.5"
    }
  }
}
locals {
  isAccountDefault = terraform.workspace == var.environment ? true : false
  domain           = local.isAccountDefault ? var.domain : "${terraform.workspace}.${var.domain}"
}
