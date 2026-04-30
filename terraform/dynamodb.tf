# ============================================================
# DynamoDB — Tables NoSQL
# ============================================================

# --- Table : users ---
resource "aws_dynamodb_table" "users" {
  name         = "${var.project_name}-users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"

  attribute {
    name = "userId"
    type = "N" # ← nombre au lieu de string
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    team = "OHazard"
    Name = "${var.project_name}-users"
  }
}

# --- Table : groups ---
resource "aws_dynamodb_table" "groups" {
  name         = "${var.project_name}-groups"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "groupId"

  attribute {
    name = "groupId"
    type = "S"
  }

  attribute {
    name = "ownerId"
    type = "S"
  }

  # GSI pour lister tous les groupes d'un user
  global_secondary_index {
    name            = "OwnerIndex"
    hash_key        = "ownerId"
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
    Name = "${var.project_name}-groups"
  }
}

