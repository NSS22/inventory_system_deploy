data "aws_iam_policy" "lambda_exec" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy" "lambda_vpc_access" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy" "xray_writeonly_access" {
  arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "inventory-system" {
  for_each = toset([
    data.aws_iam_policy.lambda_exec.arn,
    data.aws_iam_policy.lambda_vpc_access.arn,
    data.aws_iam_policy.xray_writeonly_access.arn,
  ])
  role       = "inventory-system-${var.environment}"
  policy_arn = each.value
}
