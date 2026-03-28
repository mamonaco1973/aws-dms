# ===============================================================================
# SECURELY GENERATE AND STORE CREDENTIALS FOR RDS
# ===============================================================================
# Generates random passwords and stores database credentials securely in
# AWS Secrets Manager for both Aurora and standalone RDS instances.
# ===============================================================================

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

# ==============================================================================
# MYSQL RDS: PASSWORD GENERATION
# ==============================================================================
resource "random_password" "mysql_password" {
  # ----------------------------------------------------------------------------
  # PASSWORD POLICY
  # ----------------------------------------------------------------------------
  # Generate a 24-character alphanumeric password.
  length  = 24
  special = false
}

# ==============================================================================
# MYSQL RDS: SECRETS MANAGER SECRET
# ==============================================================================
resource "aws_secretsmanager_secret" "mysql_credentials" {
  # ----------------------------------------------------------------------------
  # SECRET IDENTITY
  # ----------------------------------------------------------------------------
  # Logical name for the secret in AWS Secrets Manager.
  name        = "mysql-credentials"
  description = "root credentials for example RDS MySQL Instance"
  # ----------------------------------------------------------------------------
  # DELETION BEHAVIOR
  # ----------------------------------------------------------------------------
  # Force immediate deletion instead of a recovery window.
  recovery_window_in_days = 0
}

# ------------------------------------------------------------------------------
# MYSQL RDS: SECRET VERSION (PAYLOAD)
# ------------------------------------------------------------------------------
resource "aws_secretsmanager_secret_version" "mysql_credentials_version" {
  # Parent secret to which this version belongs.
  secret_id = aws_secretsmanager_secret.mysql_credentials.id

  # Store connection details and generated password as a JSON document.
  secret_string = jsonencode({
    user     = "admin"
    password = random_password.mysql_password.result
    endpoint = split(":", aws_db_instance.mysql_rds.endpoint)[0]
  })
}