locals {
  cors-hostsV1 = {
    "dev"     = "\"http://localhost:3001\""
  }

  corsOptions = {
    responses = {
      200 = {
        description = "200 response"
        headers = {
          "Access-Control-Allow-Origin" = {
            schema = {
              type = "string"
            }
          }
          "Access-Control-Allow-Methods" = {
            schema = {
              type = "string"
            }
          }
          "Access-Control-Allow-Headers" = {
            schema = {
              type = "string"
            }
          }
        }
        content = {}
      }
    }
    x-amazon-apigateway-integration = {
      responses = {
        default = {
          statusCode = "200"
          responseParameters = {
            "method.response.header.Access-Control-Allow-Methods" = "'POST'"
            "method.response.header.Access-Control-Allow-Headers" : "'Content-Type'"
          }
        }
      }
      requestTemplates = {
        "application/json" = "{\n \"statusCode\": 200\n}\n#set($domains = [${local.cors-hostsV1[var.environment]}])\n#set($origin = $input.params(\"origin\"))\n#if($domains.contains($origin))\n#set($context.responseOverride.header.Access-Control-Allow-Origin = $origin)\n#end"
      }
      passthroughBehavior = "never"
      type                = "mock"
    }
  }
}

resource "aws_api_gateway_rest_api" "inventory_system" {
  body = jsonencode({
    openapi = "3.0.1"
    info = {
      title   = "eks_api_gateway_stage"
      version = "1.0"
    }
    paths = {
      "/inventory-system" = {
        post = {
          x-amazon-apigateway-integration = {
            httpMethod           = "POST"
            payloadFormatVersion = "1.0"
            type                 = "AWS_PROXY"
            uri                  = "${}"
          }
        }
        options = local.corsOptions
      }
    }
  })

  name = "inventory-system-${terraform.workspace}"
}

resource "aws_api_gateway_deployment" "inventory_system" {
  rest_api_id = aws_api_gateway_rest_api.inventory_system.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.inventory_system.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "inventory_system" {
  deployment_id        = aws_api_gateway_deployment.inventory_system.id
  rest_api_id          = aws_api_gateway_rest_api.inventory_system.id
  stage_name           = "stage"
  xray_tracing_enabled = "true"
}

resource "aws_api_gateway_base_path_mapping" "inventory_system" {
  count       = local.isAccountDefault ? 1 : 0
  api_id      = aws_api_gateway_rest_api.inventory_system.id
  stage_name  = aws_api_gateway_stage.inventory_system.stage_name
  domain_name = aws_api_gateway_domain_name.inventory_system[0].domain_name
}

resource "aws_api_gateway_domain_name" "inventory_system" {
  count                    = local.isAccountDefault ? 1 : 0
  domain_name              = "inventory_system.${local.domain}"
  regional_certificate_arn = data.aws_acm_certificate.api_gateway.arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_route53_record" "inventory_system" {
  count   = local.isAccountDefault ? 1 : 0
  name    = aws_api_gateway_domain_name.inventory_system[0].domain_name
  type    = "A"
  zone_id = data.aws_route53_zone.rdg-nrem.zone_id

  alias {
    name                   = aws_api_gateway_domain_name.inventory_system[0].regional_domain_name
    zone_id                = aws_api_gateway_domain_name.inventory_system[0].regional_zone_id
    evaluate_target_health = false
  }
}

resource "aws_wafv2_web_acl_association" "inventory_system" {
  resource_arn = aws_api_gateway_stage.inventory_system.arn
  web_acl_arn  = data.aws_wafv2_web_acl.rdg-nre.arn
}
