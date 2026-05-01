# ============================================================
# SageMaker — IAM Role pour Training Jobs
# NOTE : Pas de SageMaker Endpoint (trop coûteux ~€40/mois).
#        L'inférence est assurée par la Lambda AI (ECR).
#        Ce rôle sert uniquement à lancer des Training Jobs
#        manuellement via : aws sagemaker create-training-job
# ============================================================

resource "aws_iam_role" "sagemaker_exec" {
  name = "${var.project_name}-sagemaker-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "sagemaker.amazonaws.com"
      }
    }]
  })

  tags = {
    team = "OHazard"
  }
}

# Managed policy SageMaker (accès S3, ECR, CloudWatch inclus)
resource "aws_iam_role_policy_attachment" "sagemaker_full" {
  role       = aws_iam_role.sagemaker_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# Accès inline aux buckets AI uniquement (silver + models)
resource "aws_iam_role_policy" "sagemaker_s3_policy" {
  name = "${var.project_name}-sagemaker-s3-policy"
  role = aws_iam_role.sagemaker_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.data_silver.arn,
          "${aws_s3_bucket.data_silver.arn}/*",
          aws_s3_bucket.models.arn,
          "${aws_s3_bucket.models.arn}/*",
        ]
      }
    ]
  })
}
