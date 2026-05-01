# ============================================================
# ECR — Registry Docker pour la Lambda AI
# ============================================================

resource "aws_ecr_repository" "ai_lambda" {
  name                 = "${var.project_name}-ai-lambda"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    team = "OHazard"
    Name = "${var.project_name}-ai-lambda"
  }
}

# Lifecycle policy : garder seulement les 3 dernières images (économie stockage)
resource "aws_ecr_lifecycle_policy" "ai_lambda" {
  repository = aws_ecr_repository.ai_lambda.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only last 3 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 3
      }
      action = {
        type = "expire"
      }
    }]
  })
}
