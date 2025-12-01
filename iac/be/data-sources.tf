data "aws_acm_certificate" "api_gateway" {
  domain = "inventory.${var.environment}.${var.domain}"
}

data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
