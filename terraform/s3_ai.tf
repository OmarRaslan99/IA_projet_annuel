# ============================================================
# S3 — Buckets AI (Bronze, Silver, Models)
# ============================================================

# --- Bronze : données brutes Kaggle ---
resource "aws_s3_bucket" "data_bronze" {
  bucket = "${var.project_name}-data-bronze-${var.environment}"

  tags = {
    team = "OHazard"
    Name = "${var.project_name}-data-bronze"
  }
}

resource "aws_s3_bucket_versioning" "data_bronze" {
  bucket = aws_s3_bucket.data_bronze.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_bronze" {
  bucket = aws_s3_bucket.data_bronze.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "data_bronze" {
  bucket                  = aws_s3_bucket.data_bronze.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Silver : données nettoyées + features ---
resource "aws_s3_bucket" "data_silver" {
  bucket = "${var.project_name}-data-silver-${var.environment}"

  tags = {
    team = "OHazard"
    Name = "${var.project_name}-data-silver"
  }
}

resource "aws_s3_bucket_versioning" "data_silver" {
  bucket = aws_s3_bucket.data_silver.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_silver" {
  bucket = aws_s3_bucket.data_silver.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "data_silver" {
  bucket                  = aws_s3_bucket.data_silver.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Models : artefacts .pkl entraînés ---
resource "aws_s3_bucket" "models" {
  bucket = "${var.project_name}-models-${var.environment}"

  tags = {
    team = "OHazard"
    Name = "${var.project_name}-models"
  }
}

resource "aws_s3_bucket_versioning" "models" {
  bucket = aws_s3_bucket.models.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "models" {
  bucket = aws_s3_bucket.models.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "models" {
  bucket                  = aws_s3_bucket.models.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
