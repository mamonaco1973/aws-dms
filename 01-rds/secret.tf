# ===============================================================================
# SECURELY GENERATE AND STORE CREDENTIALS FOR RDS
# ===============================================================================
# Generates random passwords and stores database credentials securely in
# AWS Secrets Manager for both Aurora and standalone RDS instances.
# ===============================================================================

# ------------------------------------------------------------------------------
# AURORA POSTGRESQL PASSWORD
# ------------------------------------------------------------------------------

# Generate a secure random alphanumeric password
resource "random_password" "aurora_password" {
  length  = 24    # Total password length in characters
  special = false # Disable special characters for client compatibility
}

# ------------------------------------------------------------------------------
# AURORA POSTGRESQL SECRETS MANAGER SECRET
# ------------------------------------------------------------------------------

# Define a Secrets Manager secret for Aurora credentials
resource "aws_secretsmanager_secret" "aurora_credentials" {
  name                    = "aurora-postgres-credentials"
  description             = "root credentials for example Aurora Postgres Instance"
  recovery_window_in_days = 0
}

# Store the Aurora credentials as a versioned secret
resource "aws_secretsmanager_secret_version" "aurora_credentials_version" {
  secret_id = aws_secretsmanager_secret.aurora_credentials.id

  # Encode credentials as JSON for downstream consumers
  secret_string = jsonencode({
    user     = "postgres"                             # Static database username
    password = random_password.aurora_password.result # Generated password
    endpoint = split(":", aws_rds_cluster.aurora_cluster.endpoint)[0]
  })
}

# ------------------------------------------------------------------------------
# STANDALONE POSTGRESQL RDS PASSWORD
# ------------------------------------------------------------------------------

# Generate a secure random alphanumeric password
resource "random_password" "postgres_password" {
  length  = 24    # Total password length in characters
  special = false # Disable special characters for client compatibility
}

# ------------------------------------------------------------------------------
# STANDALONE POSTGRESQL RDS SECRETS MANAGER SECRET
# ------------------------------------------------------------------------------

# Define a Secrets Manager secret for RDS credentials
resource "aws_secretsmanager_secret" "postgres_credentials" {
  name                    = "postgres-credentials"
  description             = "root credentials for example RDS Postgres Instance"
  recovery_window_in_days = 0
}

# Store the RDS credentials as a versioned secret
resource "aws_secretsmanager_secret_version" "postgres_credentials_version" {
  secret_id = aws_secretsmanager_secret.postgres_credentials.id

  # Encode credentials as JSON for downstream consumers
  secret_string = jsonencode({
    user     = "postgres"                               # Static database username
    password = random_password.postgres_password.result # Generated password
    endpoint = split(":", aws_db_instance.postgres_rds.endpoint)[0]
  })
}
