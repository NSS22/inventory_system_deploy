locals {
  port       = 3000
  account_id = ""
}

resource "aws_ecs_task_definition" "inventory-system" {
  family                   = "inventory-system_${var.app_version}"
  task_role_arn            = data.aws_iam_role.ecs_task_role.arn
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  requires_compatibilities = ["FARGATE"]
  container_definitions    = <<DEFINITION
[
  {
    "image": "${local.account_id}.dkr.ecr.${var.region}.amazonaws.com/inventory-system:nkb-${var.app_version}",
    "name": "inventory-system",
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-region": "${var.region}",
        "awslogs-group": "${aws_cloudwatch_log_group.inventory-system.name}",
        "awslogs-stream-prefix": "fargate"
      }
    },
    "linuxParameters": {
      "initProcessEnabled": ${var.environment == "dev" ? true : false}
    },
    "portMappings": [
      {
        "containerPort": ${local.port},
        "hostPort": ${local.port}
      }
    ],
    "environment": [
      {
        "name": "TZ",
        "value": "Europe/London"
      },
      {
        "name": "APP_VERSION",
        "value": "${var.app_version}"
      },
      {
        "name": "APP_ENVIRONMENT",
        "value": "${terraform.workspace}"
      },
      {
        "name": "WEBSITE_HOSTNAME",
        "value": "${data.aws_ssm_parameter.website_hostname.value}"
      },
      {
        "name": "SERVICES_BASE_URL",
        "value": "${data.aws_ssm_parameter.services_hostname.value}"
      },
      {
        "name": "PORT",
        "value": "${local.port}"
      },
      {
        "name": "BUNDLE_ANALYZER",
        "value": "false"
      },
      {
        "name": "NEXT_PUBLIC_START_MSW",
        "value": "false"
      },
      {
        "name": "NODE_ENV",
        "value": "production"
      }
    ],
    "secrets": [
      {
        "name": "SOURCE_PATH",
        "valueFrom": "arn:aws:ssm:${var.region}:${local.account_id}:parameter/${var.project}/${var.environment}/SOURCE_PATH"
      }
    ]
  }
]
DEFINITION
}

resource "aws_cloudwatch_log_group" "inventory-system" {
  name              = "/inventory-system/${terraform.workspace}"
  retention_in_days = 5
}

resource "random_id" "target_group_name" {
  byte_length = 8
  prefix      = "inventory-system-"
}

resource "aws_lb_target_group" "inventory-system" {
  name        = random_id.target_group_name.hex
  port        = local.port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.inventory-system.id
  target_type = "ip"
  health_check {
    path                = "/"
    interval            = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
  }
  tags = {
    Name = "inventory-system-${var.environment}-${var.app_version}"
    app  = "inventory-system"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener_rule" "inventory-system_default" {
  listener_arn = data.aws_lb_listener.inventory-system.arn
  priority     = 20
  condition {
    host_header {
      values = ["nre.${local.domain}", "nre-${local.domain}"]
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.inventory-system.arn
  }
  depends_on = [
    aws_lb_target_group.inventory-system
  ]
}

resource "aws_ecs_service" "inventory-system" {
  name                   = "inventory-system-${terraform.workspace}"
  cluster                = data.aws_ecs_cluster.inventory-system.id
  task_definition        = aws_ecs_task_definition.inventory-system.arn
  desired_count          = length(data.aws_subnets.private_subnets.ids)
  launch_type            = "FARGATE"
  enable_execute_command = var.environment == "dev" ? true : false
  network_configuration {
    subnets         = data.aws_subnets.private_subnets.ids
    security_groups = [aws_security_group.ecs_inventory-system.id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.inventory-system.arn
    container_name   = "inventory-system"
    container_port   = local.port
  }
  lifecycle {
    ignore_changes        = [desired_count]
    create_before_destroy = true
  }
}

resource "aws_route53_record" "inventory-system_version" {
  name    = "inventory-system-${terraform.workspace}"
  type    = "CNAME"
  ttl     = 60
  zone_id = data.aws_route53_zone.inventory-system.id
  records = [data.aws_lb.inventory-system.dns_name]
}

resource "aws_route53_record" "inventory-system_default" {
  count   = local.isAccountDefault ? 1 : 0
  name    = "inventory-system"
  type    = "CNAME"
  ttl     = 3600
  zone_id = data.aws_route53_zone.inventory-system.id
  records = [data.aws_lb.inventory-system.dns_name]
}

resource "aws_security_group" "ecs_inventory-system" {
  name   = "inventory-system-${terraform.workspace}-ecs"
  vpc_id = data.aws_vpc.inventory-system.id
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "${var.project}-${terraform.workspace}-ecs-inventory-system"
  }
  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_security_group_rule" "inventory-system" {
  type              = "ingress"
  from_port         = local.port
  to_port           = local.port
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.inventory-system.cidr_block]
  security_group_id = aws_security_group.ecs_inventory-system.id
}
