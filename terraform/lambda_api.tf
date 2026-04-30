# ============================================================
# Lambda -- Backend Node.js (sans VPC, acces public internet)
# ============================================================

# Aucun deploiement automatique -- le code est pousse manuellement via
# aws lambda update-function-code ou le pipeline CI/CD.
# Un fichier zip vide est requis uniquement a la creation initiale.

resource "aws_lambda_function" "backend" {
  function_name = "${var.project_name}-backend"

  # Fournir un zip lors du premier terraform apply.
  # Le code reel est deploye ensuite via : aws lambda update-function-code
  filename         = var.lambda_zip_path
  source_code_hash = filebase64sha256(var.lambda_zip_path)

  role    = aws_iam_role.lambda_exec.arn
  handler = "index.handler"
  runtime = "nodejs20.x"

  timeout              = 30
  memory_size          = 256
  reserved_concurrent_executions = 5  # Max 5 executions paralleles -- evite le scaling infini

  # Pas de vpc_config -- Lambda s'execute dans le reseau AWS managed (gratuit)

  environment {
    variables = {
      NODE_ENV           = var.environment
      DB_SECRET_ARN      = aws_secretsmanager_secret.db_credentials.arn
      DYNAMODB_USERS     = aws_dynamodb_table.users.name
      DYNAMODB_GROUPS    = aws_dynamodb_table.groups.name
      ALLOWED_ORIGIN     = "https://${aws_cloudfront_distribution.frontend.domain_name}"
    }
  }

  tags = {
    team = "OHazard"
    Name = "${var.project_name}-backend"
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.lambda
  ]
}

# Log group CloudWatch pour la Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-backend"
  retention_in_days = 14

  tags = {
    team = "OHazard"
  }
}

# ============================================================
# API Gateway HTTP -- expose la Lambda via HTTPS
# ============================================================

resource "aws_apigatewayv2_api" "backend" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
  description   = "API Gateway HTTP pour le backend OHazard"

  cors_configuration {
    allow_origins = ["https://${aws_cloudfront_distribution.frontend.domain_name}"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }

  tags = {
    team = "OHazard"
  }
}

resource "aws_apigatewayv2_stage" "backend" {
  api_id      = aws_apigatewayv2_api.backend.id
  name        = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn

    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = {
    team = "OHazard"
  }
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}"
  retention_in_days = 14

  tags = {
    team = "OHazard"
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id             = aws_apigatewayv2_api.backend.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.backend.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "proxy" {
  api_id    = aws_apigatewayv2_api.backend.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.backend.execution_arn}/*/*"
}
