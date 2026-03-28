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
# POSTGRESQL RDS READ REPLICA
# ===============================================================================
# Creates a read replica of the standalone RDS instance for read scaling and
# additional redundancy. Many settings are inherited from the source DB.
# ===============================================================================

resource "aws_db_instance" "postgres_rds_replica" {

  # Unique identifier for the replica instance
  identifier = "postgres-rds-replica"

  # Link replica to the source (primary) DB instance
  replicate_source_db = aws_db_instance.postgres_rds.arn

  # Engine must match the source DB engine
  engine = aws_db_instance.postgres_rds.engine

  # Engine version should match source (minor upgrades may be supported)
  engine_version = aws_db_instance.postgres_rds.engine_version

  # Instance class for the replica
  instance_class = "db.t4g.micro"

  # Subnet group used for VPC placement
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name

  # Security groups controlling replica access
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  # Public access for dev only; avoid for production
  publicly_accessible = true

  # Enable Performance Insights for query-level metrics
  performance_insights_enabled = true

  # Skip final snapshot on destroy (unsafe for production)
  skip_final_snapshot = true

  # -----------------------------------------------------------------------------
  # INHERITED FROM SOURCE DB
  # -----------------------------------------------------------------------------
  # These values are inherited from the source instance and typically should not
  # be set explicitly on the replica:
  # - allocated_storage
  # - db_name
  # - username / password
  # - multi_az
  # - backup_retention_period
  # - backup_window
  # -----------------------------------------------------------------------------

  tags = {
    Name = "Postgres RDS Read Replica"
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
