provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      Environment  = upper(var.environment)
      Owner        = "NSS"
      Project      = upper(var.project)
      TF_WORKSPACE = terraform.workspace
    }
  }
}
data "aws_caller_identity" "current" {}
