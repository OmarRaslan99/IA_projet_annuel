# ============================================================
# IAM -- Groupe OHazard + Policies + Role Lambda
# ============================================================

# --- Reference au groupe OHazard existant (gere en dehors de Terraform) ---
data "aws_iam_group" "ohazard" {
  group_name = "OHazard"
}

# --- Politique pour acceder aux ressources du projet ---
resource "aws_iam_policy" "ohazard_policy" {
  name        = "${var.project_name}-team-policy"
  description = "Politique d'acces pour les membres de l'equipe OHazard"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 -- lecture et ecriture (deploiement manuel du front via aws s3 sync)
      {
        Sid    = "S3FrontendReadWrite"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:ListBucketVersions",
          "s3:GetObjectVersion",
          "s3:DeleteObjectVersion"
        ]
        Resource = [
          aws_s3_bucket.frontend.arn,
          "${aws_s3_bucket.frontend.arn}/*"
        ]
      },
      # Lambda -- lecture, deploiement et invocation
      {
        Sid    = "LambdaAccess"
        Effect = "Allow"
        Action = [
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:GetFunctionCodeSigningConfig",
          "lambda:ListFunctions",
          "lambda:ListVersionsByFunction",
          "lambda:ListAliases",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:UpdateFunctionEventInvokeConfig",
          "lambda:InvokeFunction",
          "lambda:CreateFunction",
          "lambda:DeleteFunction",
          "lambda:PublishVersion",
          "lambda:CreateAlias",
          "lambda:UpdateAlias",
          "lambda:DeleteAlias",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:GetPolicy"
        ]
        Resource = [
          aws_lambda_function.backend.arn,
          "${aws_lambda_function.backend.arn}:*"
        ]
      },
      # DynamoDB -- acces aux deux tables du projet
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = [
          aws_dynamodb_table.users.arn,
          "${aws_dynamodb_table.users.arn}/index/*",
          aws_dynamodb_table.groups.arn,
          "${aws_dynamodb_table.groups.arn}/index/*"
        ]
      },
      # RDS -- connexion et gestion
      {
        Sid    = "RDSAccess"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "rds-db:connect"
        ]
        Resource = "*"
      },
      # Route53 -- lecture des zones
      {
        Sid    = "Route53ReadAccess"
        Effect = "Allow"
        Action = [
          "route53:GetHostedZone",
          "route53:ListResourceRecordSets",
          "route53:ListHostedZones"
        ]
        Resource = "*"
      },
      # CloudWatch Logs -- lecture des logs Lambda et API Gateway
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/${var.project_name}-*"
      },
      # S3 AI -- lecture/ecriture buckets bronze, silver, models
      {
        Sid    = "S3AIReadWrite"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.data_bronze.arn,
          "${aws_s3_bucket.data_bronze.arn}/*",
          aws_s3_bucket.data_silver.arn,
          "${aws_s3_bucket.data_silver.arn}/*",
          aws_s3_bucket.models.arn,
          "${aws_s3_bucket.models.arn}/*"
        ]
      },
      # ECR -- push/pull images Docker Lambda AI
      {
        Sid    = "ECRAccess"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages"
        ]
        Resource = "*"
      },
      # SageMaker -- lancement manuel de Training Jobs
      {
        Sid    = "SageMakerTrainingJobs"
        Effect = "Allow"
        Action = [
          "sagemaker:CreateTrainingJob",
          "sagemaker:DescribeTrainingJob",
          "sagemaker:StopTrainingJob",
          "sagemaker:ListTrainingJobs"
        ]
        Resource = "*"
      },
      # DynamoDB AI -- table predictions
      {
        Sid    = "DynamoDBAIPredictions"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = [
          aws_dynamodb_table.predictions.arn,
          "${aws_dynamodb_table.predictions.arn}/index/*"
        ]
      }
    ]
  })

  tags = {
    team = "OHazard"
  }
}

# --- Attacher la politique au groupe (les users sont deja membres) ---
resource "aws_iam_group_policy_attachment" "ohazard_attach" {
  group      = data.aws_iam_group.ohazard.group_name
  policy_arn = aws_iam_policy.ohazard_policy.arn
}

# ============================================================
# Role IAM pour la Lambda (execution role)
# ============================================================
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = {
    team = "OHazard"
  }
}

# Execution basique -- ecriture CloudWatch Logs uniquement (pas besoin du VPC policy)
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Politique inline pour acces DynamoDB + RDS + Secrets Manager depuis Lambda
resource "aws_iam_role_policy" "lambda_app_policy" {
  name = "${var.project_name}-lambda-app-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.users.arn,
          "${aws_dynamodb_table.users.arn}/index/*",
          aws_dynamodb_table.groups.arn,
          "${aws_dynamodb_table.groups.arn}/index/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["rds-db:connect"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.db_credentials.arn
      },
      # DynamoDB predictions -- le backend web écrit les prédictions AI
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.predictions.arn,
          "${aws_dynamodb_table.predictions.arn}/index/*"
        ]
      }
    ]
  })
}
