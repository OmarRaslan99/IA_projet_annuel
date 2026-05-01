# ============================================================
# Outputs -- valeurs exposees apres terraform apply
# ============================================================

# --- URLs ---
output "frontend_url" {
  description = "URL du frontend Vue.js (CloudFront)"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "api_url" {
  description = "URL de l'API backend (API Gateway)"
  value       = aws_apigatewayv2_stage.backend.invoke_url
}

# --- S3 & CloudFront ---
output "s3_bucket_name" {
  description = "Nom du bucket S3 frontend -- utilise pour deployer le build Vue.js"
  value       = aws_s3_bucket.frontend.id
}

output "cloudfront_distribution_id" {
  description = "ID CloudFront -- utilise pour invalider le cache apres deploiement"
  value       = aws_cloudfront_distribution.frontend.id
}

# --- Lambda ---
output "lambda_function_name" {
  description = "Nom de la Lambda backend -- utilise pour deployer le code Node.js"
  value       = aws_lambda_function.backend.function_name
}

# --- DynamoDB ---
output "dynamodb_users_table_name" {
  description = "Nom de la table DynamoDB users"
  value       = aws_dynamodb_table.users.name
}

output "dynamodb_groups_table_name" {
  description = "Nom de la table DynamoDB groups"
  value       = aws_dynamodb_table.groups.name
}

# --- RDS ---
output "rds_endpoint" {
  description = "Endpoint Aurora PostgreSQL -- masque car sensible"
  value       = aws_rds_cluster.postgres.endpoint
  sensitive   = true
}

output "rds_port" {
  description = "Port Aurora PostgreSQL"
  value       = aws_rds_cluster.postgres.port
}

output "db_secret_arn" {
  description = "ARN du secret Secrets Manager -- passe en variable d'environnement Lambda"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

# --- IAM ---
output "iam_group_name" {
  description = "Nom du groupe IAM OHazard"
  value       = data.aws_iam_group.ohazard.group_name
}

output "lambda_exec_role_arn" {
  description = "ARN du role d'execution Lambda"
  value       = aws_iam_role.lambda_exec.arn
}

# --- API Gateway ---
output "api_gateway_id" {
  description = "ID de l'API Gateway"
  value       = aws_apigatewayv2_api.backend.id
}

# ============================================================
# Outputs AI
# ============================================================

# --- S3 AI ---
output "s3_bronze_bucket" {
  description = "Bucket S3 données brutes (bronze)"
  value       = aws_s3_bucket.data_bronze.id
}

output "s3_silver_bucket" {
  description = "Bucket S3 données préparées (silver)"
  value       = aws_s3_bucket.data_silver.id
}

output "s3_models_bucket" {
  description = "Bucket S3 artefacts modèles (.pkl)"
  value       = aws_s3_bucket.models.id
}

# --- ECR ---
output "ecr_repository_url" {
  description = "URL du repo ECR -- utiliser pour docker push et comme ai_lambda_image_uri"
  value       = aws_ecr_repository.ai_lambda.repository_url
}

# --- DynamoDB predictions ---
output "dynamodb_predictions_table_name" {
  description = "Nom de la table DynamoDB predictions"
  value       = aws_dynamodb_table.predictions.name
}

# --- Lambda AI ---
output "ai_predict_url" {
  description = "URL de l'endpoint AI predict (disponible après déploiement de l'image ECR)"
  value       = var.ai_lambda_image_uri != "" ? "${aws_apigatewayv2_stage.backend.invoke_url}/ai/predict" : "Image ECR non déployée -- définir ai_lambda_image_uri dans terraform.tfvars"
}

# --- SageMaker ---
output "sagemaker_exec_role_arn" {
  description = "ARN du rôle SageMaker -- passer à create-training-job"
  value       = aws_iam_role.sagemaker_exec.arn
}