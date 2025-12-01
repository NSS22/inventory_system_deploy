locals {
  cidr_groups         = cidrsubnets(var.cidr_block, 2, 2, 2, 2)
  public_subnets_cidr = cidrsubnets(local.cidr_groups[0], 2, 2, 2, 2)
  spare_subnet_cidr   = cidrsubnet(local.cidr_groups[0], 2, 3)
}

resource "aws_vpc" "inventory_system" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    "Name" = "inventory-system-${terraform.workspace}"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.inventory_system
  count                   = var.environment == "dev" ? 2 : length(data.aws_availability_zones.available.names)
  cidr_block              = local.public_subnets_cidr[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags = {
    "type" = "public"
    "Name" = "public-${data.aws_availability_zones.available.names[count.index]}"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.nre-services.id
  count             = var.environment == "dev" ? 2 : length(data.aws_availability_zones.available.names)
  cidr_block        = local.cidr_groups[count.index + 1]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    "type" = "private"
    "Name" = "private-${data.aws_availability_zones.available.names[count.index]}"
  }
}

resource "aws_route_table" "private" {
  count  = length(aws_nat_gateway.public_subnet)
  vpc_id = aws_vpc.inventory_system
  tags = {
    "Name" = "private-${data.aws_availability_zones.available.names[count.index]}"
  }
}

resource "aws_route" "private" {
  count                  = length(aws_route_table.private)
  route_table_id         = aws_route_table.private[count.index]
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.public_subnet[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_nat_gateway" "public_subnet" {
  count = length(aws_subnet.public)
  subnet_id = aws_subnet.public[count.index].id
  allocation_id = aws_eip.internet[count.index].id
}

resource "aws_eip" "internet" {
  count  = length(aws_subnet.private)
  domain = "vpc"
}

resource "aws_internet_gateway" "internet" {
  vpc_id = aws_vpc.inventory_system
}

resource "aws_route" "internet" {
  count                  = length(data.aws_availability_zones.available.names)
  route_table_id         = aws_vpc.inventory_system.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet.id
}

resource "aws_security_group" "inventory_system" {
  name   = "inventory_system"
  count  = var.environment == terraform.workspace ? 1 : 0
  egress = {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project}-${terraform.workspace}-inventory_system"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.nre-services.id
}
