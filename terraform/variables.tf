variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-west-3" # Paris
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "ohazard"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# domain_name supprimé -- URLs AWS natives utilisées (CloudFront + API Gateway)

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "ohazarddb"
}

variable "db_username" {
  description = "PostgreSQL master username"
  type        = string
  default     = "ohazardadmin"
  sensitive   = true
}

variable "db_password" {
  description = "PostgreSQL master password"
  type        = string
  sensitive   = true
}

variable "iam_users" {
  description = "List of IAM users to create and add to the OHazard group"
  type        = list(string)
  default     = []
}

variable "lambda_zip_path" {
  description = "Path to the Lambda zip file"
  type        = string
}