# ============================================================
# Lambda AI — Inférence via image Docker ECR
# ============================================================

# Rôle IAM dédié à la Lambda AI (séparé du rôle Lambda backend)
resource "aws_iam_role" "ai_lambda_exec" {
  name = "${var.project_name}-ai-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = {
    team = "OHazard"
  }
}

resource "aws_iam_role_policy_attachment" "ai_lambda_basic" {
  role       = aws_iam_role.ai_lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Accès S3 models (lecture) + S3 silver (lecture)
resource "aws_iam_role_policy" "ai_lambda_app_policy" {
  name = "${var.project_name}-ai-lambda-app-policy"
  role = aws_iam_role.ai_lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.models.arn,
          "${aws_s3_bucket.models.arn}/*",
          aws_s3_bucket.data_silver.arn,
          "${aws_s3_bucket.data_silver.arn}/*",
        ]
      }
    ]
  })
}

# Log group CloudWatch pour la Lambda AI
resource "aws_cloudwatch_log_group" "ai_lambda" {
  name              = "/aws/lambda/${var.project_name}-ai-predict"
  retention_in_days = 14

  tags = {
    team = "OHazard"
  }
}

# Lambda AI — image Docker depuis ECR
# Déployée uniquement si l'image ECR est disponible (ai_lambda_image_uri != "")
resource "aws_lambda_function" "ai_predict" {
  count = var.ai_lambda_image_uri != "" ? 1 : 0

  function_name = "${var.project_name}-ai-predict"
  role          = aws_iam_role.ai_lambda_exec.arn

  package_type = "Image"
  image_uri    = var.ai_lambda_image_uri

  timeout     = 60    # chargement modèles depuis S3 au cold start
  memory_size = 1024  # scikit-learn + xgboost nécessitent de la mémoire

  # Max 3 exécutions parallèles — limiter les coûts
  reserved_concurrent_executions = 3

  environment {
    variables = {
      MODELS_BUCKET        = aws_s3_bucket.models.id
      OUTCOME_MODEL_KEY    = "outcome_model.pkl"
      SCORE_HOME_MODEL_KEY = "score_home_model.pkl"
      SCORE_AWAY_MODEL_KEY = "score_away_model.pkl"
      S3_SILVER_BUCKET     = aws_s3_bucket.data_silver.id
      SILVER_KEY           = "matches_features.parquet"
      AWS_REGION           = var.aws_region
      ENVIRONMENT          = var.environment
    }
  }

  tags = {
    team = "OHazard"
    Name = "${var.project_name}-ai-predict"
  }

  depends_on = [
    aws_iam_role_policy_attachment.ai_lambda_basic,
    aws_cloudwatch_log_group.ai_lambda,
  ]
}

# ============================================================
# API Gateway — Nouvelle route POST /ai/predict
# Réutilise l'API Gateway existant (aws_apigatewayv2_api.backend)
# ============================================================

resource "aws_apigatewayv2_integration" "ai_lambda" {
  count = var.ai_lambda_image_uri != "" ? 1 : 0

  api_id             = aws_apigatewayv2_api.backend.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.ai_predict[0].invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "ai_predict" {
  count = var.ai_lambda_image_uri != "" ? 1 : 0

  api_id    = aws_apigatewayv2_api.backend.id
  route_key = "POST /ai/predict"
  target    = "integrations/${aws_apigatewayv2_integration.ai_lambda[0].id}"
}

resource "aws_lambda_permission" "ai_api_gateway" {
  count = var.ai_lambda_image_uri != "" ? 1 : 0

  statement_id  = "AllowExecutionFromAPIGatewayAI"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ai_predict[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.backend.execution_arn}/*/*"
}
