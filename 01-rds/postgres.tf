# ===============================================================================
# STANDALONE POSTGRESQL RDS INSTANCE
# ===============================================================================
# Provisions a standard PostgreSQL RDS instance. This is NOT Aurora and does
# not use Aurora cluster semantics or Serverless capacity scaling.
# ===============================================================================

resource "aws_db_instance" "postgres_rds" {

  # Unique identifier for the RDS instance
  identifier = "postgres-rds-instance"

  # Standard PostgreSQL engine (not Aurora)
  engine = "postgres"

  # PostgreSQL engine version supported by AWS - if blank default 
  # version is used

  # engine_version = "15.12"

  # Instance class sized for low-cost dev and test workloads
  instance_class = "db.t4g.micro"

  # Allocated storage in GiB (20 GiB is the typical minimum for PostgreSQL)
  allocated_storage = 20

  # Storage type for the DB volume
  storage_type = "gp3"

  # Default database created at instance initialization
  db_name = "postgres"

  # Master credentials for the DB instance
  username = "postgres"
  password = random_password.postgres_password.result

  # Subnet group must span multiple AZs for Multi-AZ deployments
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name

  # Security groups controlling DB access
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  # Enable Multi-AZ standby for failover
  multi_az = true

  # Public access for dev only; avoid for production
  publicly_accessible = true

  # Skip final snapshot on destroy (unsafe for production)
  skip_final_snapshot = true

  # Retain automated backups for N days
  backup_retention_period = 5

  # Preferred backup window (UTC)
  backup_window = "07:00-09:00"

  # Enable Performance Insights for query-level metrics
  performance_insights_enabled = true

  tags = {
    Name = "Postgres RDS Instance"
  }
}


# ===============================================================================
# RDS DB SUBNET GROUP
# ===============================================================================
# Defines the subnets used for RDS ENI placement. For high availability, the
# subnet list must span at least two availability zones.
# ===============================================================================

resource "aws_db_subnet_group" "rds_subnet_group" {

  # Name of the DB subnet group
  name = "postgres-subnet-group"

  # Subnets used for DB placement (must span multiple AZs)
  subnet_ids = [
    aws_subnet.rds-subnet-1.id,
    aws_subnet.rds-subnet-2.id
  ]

  tags = {
    Name = "postgres-subnet-group"
  }
}
