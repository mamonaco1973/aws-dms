# ===============================================================================
# AURORA POSTGRESQL CLUSTER (SERVERLESS V2)
# ===============================================================================
# Defines an Aurora PostgreSQL cluster using Serverless v2 capacity
# scaling. Serverless v2 requires the provisioned engine mode.
# ===============================================================================

resource "aws_rds_cluster" "aurora_cluster" {

  # -----------------------------------------------------------------------------
  # IDENTIFICATION
  # -----------------------------------------------------------------------------
  # Logical identifier for the Aurora PostgreSQL cluster
  cluster_identifier = "aurora-postgres-cluster"

  # -----------------------------------------------------------------------------
  # ENGINE CONFIGURATION
  # -----------------------------------------------------------------------------
  # Aurora PostgreSQL-compatible database engine
  engine = "aurora-postgresql"

  # Engine version supporting Aurora Serverless v2
  engine_version = "15.12"

  # Serverless v2 requires provisioned engine mode
  engine_mode = "provisioned"

  # -----------------------------------------------------------------------------
  # DATABASE INITIALIZATION
  # -----------------------------------------------------------------------------
  # Default database created during cluster initialization
  database_name = "postgres"

  # Master credentials for the cluster
  master_username = "postgres"
  master_password = random_password.aurora_password.result

  # -----------------------------------------------------------------------------
  # NETWORKING
  # -----------------------------------------------------------------------------
  # Subnet group spanning multiple availability zones
  db_subnet_group_name = aws_db_subnet_group.aurora_subnet_group.name

  # Security groups controlling cluster network access
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  # -----------------------------------------------------------------------------
  # BACKUP AND LIFECYCLE
  # -----------------------------------------------------------------------------
  # Disable final snapshot on destroy (unsafe for production)
  skip_final_snapshot = true

  # Number of days to retain automated backups
  backup_retention_period = 5

  # Preferred backup window in UTC
  preferred_backup_window = "07:00-09:00"

  # -----------------------------------------------------------------------------
  # SERVERLESS V2 SCALING
  # -----------------------------------------------------------------------------
  # Aurora Capacity Units (ACUs) auto-scaling configuration
  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 4.0
  }
}

# ===============================================================================
# AURORA CLUSTER INSTANCE - PRIMARY (WRITER)
# ===============================================================================
# Primary writer instance for the Aurora PostgreSQL cluster.
# ===============================================================================

resource "aws_rds_cluster_instance" "aurora_instance_primary" {

  # Unique identifier for the primary instance
  identifier = "aurora-postgres-instance-1"

  # Associate instance with the Aurora cluster
  cluster_identifier = aws_rds_cluster.aurora_cluster.id

  # Serverless v2 instance class
  instance_class = "db.serverless"

  # Reuse cluster engine and version
  engine         = aws_rds_cluster.aurora_cluster.engine
  engine_version = aws_rds_cluster.aurora_cluster.engine_version

  # Subnet group used by the cluster
  db_subnet_group_name = aws_db_subnet_group.aurora_subnet_group.name

  # Public access enabled for testing only
  publicly_accessible = true

  # Enable Performance Insights
  performance_insights_enabled = true
}

# ===============================================================================
# AURORA CLUSTER INSTANCE - REPLICA (READER)
# ===============================================================================
# Read replica instance for high availability and read scaling.
# ===============================================================================

resource "aws_rds_cluster_instance" "aurora_instance_replica" {

  # Unique identifier for the replica instance
  identifier = "aurora-postgres-instance-2"

  # Associate instance with the Aurora cluster
  cluster_identifier = aws_rds_cluster.aurora_cluster.id

  # Serverless v2 instance class
  instance_class = "db.serverless"

  # Reuse cluster engine and version
  engine         = aws_rds_cluster.aurora_cluster.engine
  engine_version = aws_rds_cluster.aurora_cluster.engine_version

  # Subnet group used by the cluster
  db_subnet_group_name = aws_db_subnet_group.aurora_subnet_group.name

  # Public access enabled for testing only
  publicly_accessible = true

  # Enable Performance Insights
  performance_insights_enabled = true
}

# ===============================================================================
# AURORA DB SUBNET GROUP
# ===============================================================================
# Defines subnets used by Aurora for ENI placement.
# ===============================================================================

resource "aws_db_subnet_group" "aurora_subnet_group" {

  # Name of the DB subnet group
  name = "aurora-postgres-subnet-group"

  # Private subnets spanning multiple availability zones
  subnet_ids = [
    aws_subnet.rds-subnet-1.id,
    aws_subnet.rds-subnet-2.id
  ]

  tags = {
    Name = "aurora-postgres-subnet-group"
  }
}
