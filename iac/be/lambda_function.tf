locals {
  TZ = "Europe/London"
}

resource "random_id" "lambda_suffix" {
  byte_length = 4
}

resource "aws_lambda_function" "inventory-system-proxy" {
  environment {
    variables = {
      Environment                         = var.environment
      NODE_ENV                            = data.aws_ssm_parameter.node_env.value
      TZ                                  = local.TZ
      AllowedOrigins                      = local.cors-hostsV1[var.environment]
      AWS_XRAY_CONTEXT_MISSING            = "IGNORE_ERROR"
      AWS_NODEJS_CONNECTION_REUSE_ENABLED = 1
    }
  }

  ephemeral_storage {
    size = "512"
  }
  function_name                  = "inventory-system-proxy-${terraform.workspace}"
  description                    = "Inventory System API Function"
  handler                        = "handler.handler"
  memory_size                    = "512"
  package_type                   = "Zip"
  reserved_concurrent_executions = "-1"
  role                           = data.aws_iam_role.inventory-system-proxy.arn
  runtime                        = "nodejs22.x"
  filename                       = "${path.module}/../../inventory-system-proxy.zip"
  source_code_hash               = filebase64sha256("${path.module}/../../inventory-system-proxy.zip")
  timeout                        = "100"
  vpc_config {
    security_group_ids = [data.aws_security_group.inventory-system.id]
    subnet_ids         = data.aws_subnets.private_subnets.ids
  }
  tracing_config {
    mode = "Active"
  }
}
