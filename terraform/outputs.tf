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