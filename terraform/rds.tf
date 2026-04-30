# ============================================================
# Aurora Serverless v2 -- PostgreSQL
# ============================================================

resource "aws_rds_cluster" "postgres" {
  cluster_identifier      = "${var.project_name}-postgres"
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"  # obligatoire pour Serverless v2
  engine_version          = "16.4"
  database_name           = var.db_name
  master_username         = var.db_username
  master_password         = var.db_password
  storage_encrypted       = true
  skip_final_snapshot     = true
  deletion_protection     = false

  # Serverless v2 scaling -- descend à 0.5 ACU au repos (~0.06$/h min)
  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 4.0
  }

  # Backups désactivés (projet scolaire)
  backup_retention_period = 1  # minimum autorisé par Aurora, pas 0

  # Logs PostgreSQL vers CloudWatch
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    team = "OHazard"
    Name = "${var.project_name}-postgres"
  }
}

resource "aws_rds_cluster_instance" "postgres" {
  identifier           = "${var.project_name}-postgres-instance"
  cluster_identifier   = aws_rds_cluster.postgres.id
  instance_class       = "db.serverless"  # classe spéciale pour Serverless v2
  engine               = aws_rds_cluster.postgres.engine
  engine_version       = aws_rds_cluster.postgres.engine_version
  publicly_accessible  = true

  tags = {
    team = "OHazard"
    Name = "${var.project_name}-postgres-instance"
  }
}

# ============================================================
# Secrets Manager -- stocker les credentials RDS
# ============================================================

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}/db/credentials"
  description             = "Credentials Aurora PostgreSQL pour OHazard"
  recovery_window_in_days = 0

  tags = {
    team = "OHazard"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = aws_rds_cluster.postgres.endpoint
    port     = aws_rds_cluster.postgres.port
    dbname   = var.db_name
    url      = "postgresql://${var.db_username}:${var.db_password}@${aws_rds_cluster.postgres.endpoint}:${aws_rds_cluster.postgres.port}/${var.db_name}"
  })
}
