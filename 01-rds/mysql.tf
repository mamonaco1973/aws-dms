# ==============================================================================
# STANDALONE MYSQL RDS INSTANCE
# ==============================================================================
# Provisions a standalone Amazon RDS MySQL instance intended for small
# test or development workloads.
#
# Notes:
# - Uses a burstable instance class for cost efficiency.
# - Multi-AZ is enabled for automatic failover.
# - This is NOT Aurora; storage and scaling characteristics differ.
# ==============================================================================

# ------------------------------------------------------------------------------
# CONFIG
# ------------------------------------------------------------------------------
variable "mysql_track" {
  type        = string
  description = "MySQL track to pin (ex: 8.4 or 8.0)."
  default     = "8.4"
}

locals {
  mysql_parameter_group_family = "mysql${var.mysql_track}"
}

resource "aws_db_instance" "mysql_rds" {
  # ----------------------------------------------------------------------------
  # CORE IDENTIFIERS
  # ----------------------------------------------------------------------------
  # Logical identifier for the RDS instance.
  identifier = "mysql-rds-instance"

  # ----------------------------------------------------------------------------
  # ENGINE / INSTANCE SHAPE
  # ----------------------------------------------------------------------------
  # MySQL engine family.
  engine         = "mysql"
  engine_version = var.mysql_track

  # Small, burstable instance class suitable for dev/test.
  instance_class = "db.t4g.micro"

  # ----------------------------------------------------------------------------
  # STORAGE
  # ----------------------------------------------------------------------------
  # Allocated storage in GB (20 GB is the MySQL minimum).
  allocated_storage = 20

  # General Purpose SSD (gp3).
  storage_type = "gp3"

  # ----------------------------------------------------------------------------
  # DATABASE BOOTSTRAP
  # ----------------------------------------------------------------------------
  # Initial database created at instance launch.
  db_name = "mydb"

  # ----------------------------------------------------------------------------
  # MASTER CREDENTIALS
  # ----------------------------------------------------------------------------
  # Master username for database access.
  username = "admin"

  # Master password sourced from a random_password resource.
  password = random_password.mysql_password.result

  # ----------------------------------------------------------------------------
  # NETWORKING / ACCESS CONTROL
  # ----------------------------------------------------------------------------
  # Subnet group defining which VPC subnets RDS can use.
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name

  # Security groups controlling inbound and outbound access.
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  # Expose the instance endpoint publicly.
  publicly_accessible = true

  # ----------------------------------------------------------------------------
  # HIGH AVAILABILITY
  # ----------------------------------------------------------------------------
  # Enable Multi-AZ for automatic failover.
  multi_az = true

  # ----------------------------------------------------------------------------
  # BACKUPS / LIFECYCLE
  # ----------------------------------------------------------------------------
  # Skip final snapshot on destroy (not recommended for prod).
  skip_final_snapshot = true

  # Retain automated backups for N days.
  backup_retention_period = 5

  # Daily backup window (UTC).
  backup_window = "07:00-09:00"

  # ----------------------------------------------------------------------------
  # OBSERVABILITY
  # ----------------------------------------------------------------------------
  # Disable Performance Insights.
  performance_insights_enabled = false

  # ----------------------------------------------------------------------------
  # PARAMETER GROUP
  # ----------------------------------------------------------------------------
  # Custom MySQL parameter group.
  parameter_group_name = aws_db_parameter_group.mysql_custom_params.name

  # ----------------------------------------------------------------------------
  # TAGGING
  # ----------------------------------------------------------------------------
  # Resource tags.
  tags = {
    Name = "MySQL RDS Instance"
  }
}


# ==============================================================================
# MYSQL PARAMETER GROUP
# ==============================================================================
# Custom MySQL parameter group for database-level configuration.
# ==============================================================================
resource "aws_db_parameter_group" "mysql_custom_params" {
  # Name of the parameter group.
  name = "mysql-custom-params"

  # Parameter group family (must match MySQL major version).
  family = local.mysql_parameter_group_family

  # Description of the parameter group.
  description = "Custom MySQL parameters"

  # ----------------------------------------------------------------------------
  # PARAMETERS
  # ----------------------------------------------------------------------------
  # Allow creation of stored functions without SUPER privilege.
  parameter {
    name  = "log_bin_trust_function_creators"
    value = "1"
  }
}