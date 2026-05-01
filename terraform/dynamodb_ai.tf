# ============================================================
# DynamoDB — Table predictions (paris de l'IA et des users)
# ============================================================

# --- Table : predictions ---
# hash_key  : matchId  — identifiant unique du match (ex: "FRA-GER-2026-06-15")
# range_key : userId   — ID de l'utilisateur ou 0 pour l'IA
resource "aws_dynamodb_table" "predictions" {
  name         = "${var.project_name}-predictions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "matchId"
  range_key    = "userId"

  attribute {
    name = "matchId"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "N"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  # GSI : récupérer toutes les prédictions d'un user
  global_secondary_index {
    name            = "UserPredictionsIndex"
    hash_key        = "userId"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    team = "OHazard"
    Name = "${var.project_name}-predictions"
  }
}
