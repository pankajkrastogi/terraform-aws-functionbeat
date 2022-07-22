data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "vpc_execution_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role" "lambda_execution_role" {
  name               = "FunctionBeat-${var.lambda_config.name}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "vpc_execution_policy" {
  policy_arn = data.aws_iam_policy.vpc_execution_policy.arn
  role       = aws_iam_role.lambda_execution_role.id
}

resource "aws_lambda_permission" "allow_invoke_lambda_from_cloudwatch" {
  count          = var.loggroup_name != null ? 1 : 0
  statement_id   = "AllowTriggerFromCloudwatchLogGroup"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.functionbeat.function_name
  principal      = format("logs.%s.amazonaws.com", var.aws_region)
  source_account = var.aws_account_id
  source_arn     = format("arn:aws:logs:%s:%s:log-group:%s:*", var.aws_region, var.aws_account_id, var.loggroup_name)
}

resource "aws_iam_role_policy" "es_write_access" {
  name   = "es_write_access"
  role   = aws_iam_role.lambda_execution_role.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Sid : "AllowProcessorWriteToES",
        Effect : "Allow",
        Action : [
          "es:ESHttpPut",
          "es:ESHttpPost"
        ],
        Resource : [
          "arn:aws:es:${var.aws_region}:${var.aws_account_id}:domain/rdp-newsflo-es-dev/*",
          "arn:aws:es:${var.aws_region}:${var.aws_account_id}:domain/rdp-newsflo-es-dev"
        ]
      }
    ]
  })
}