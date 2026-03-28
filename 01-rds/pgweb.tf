# ==============================================================================
# FETCH UBUNTU 24.04 AMI (PGWEB HOST)
# ==============================================================================
# Retrieves the Canonical-published Ubuntu 24.04 AMI ID from AWS Systems
# Manager Parameter Store. This AMI is used for the pgweb EC2 instance
# that provides a web UI for PostgreSQL administration.
# ==============================================================================

data "aws_ssm_parameter" "ubuntu_24_04" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# ==============================================================================
# RESOLVE UBUNTU AMI METADATA
# ==============================================================================
# Resolves the full AMI object using the ID returned from SSM.
#
# Notes:
# - Owner is restricted to Canonical to prevent spoofed AMIs.
# - most_recent is enabled as a safety guard if duplicates exist.
# ==============================================================================

data "aws_ami" "ubuntu_ami" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.ubuntu_24_04.value]
  }
}

# ==============================================================================
# RESOURCE: PGWEB EC2 INSTANCE
# ==============================================================================
# Purpose:
#   Hosts pgweb, a lightweight web UI for interacting with PostgreSQL.
#
# Architecture:
#   - Connects to Aurora PostgreSQL and standalone RDS PostgreSQL.
#   - Intended for administrative and demo use only.
#   - Access may be restricted via security groups or SSM.
# ==============================================================================

resource "aws_instance" "pgweb-instance" {

  # ----------------------------------------------------------------------------
  # AMI AND INSTANCE TYPE
  # ----------------------------------------------------------------------------
  # Uses the latest Ubuntu 24.04 AMI resolved via SSM.
  # Instance size is suitable for pgweb and light admin workloads.
  # ----------------------------------------------------------------------------
  ami           = data.aws_ami.ubuntu_ami.id
  instance_type = "t3.medium"

  # ----------------------------------------------------------------------------
  # NETWORKING
  # ----------------------------------------------------------------------------
  # Places the instance in the RDS VPC subnet.
  # Inbound access is governed by the attached security group.
  # ----------------------------------------------------------------------------
  subnet_id                   = aws_subnet.rds-subnet-1.id
  vpc_security_group_ids      = [aws_security_group.http_sg.id]
  associate_public_ip_address = true

  # ----------------------------------------------------------------------------
  # IAM / SSM ACCESS
  # ----------------------------------------------------------------------------
  # Attaches an IAM role that allows registration with AWS Systems Manager
  # for secure, agent-based access if required.
  # ----------------------------------------------------------------------------
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name

  # ----------------------------------------------------------------------------
  # USER DATA
  # ----------------------------------------------------------------------------
  # Cloud-init script that installs pgweb and configures connections to:
  #   - Aurora PostgreSQL
  #   - Standalone RDS PostgreSQL
  #
  # Credentials and endpoints are injected at boot time.
  # ----------------------------------------------------------------------------
  user_data = templatefile("${path.module}/scripts/install_pgweb.sh", {
    AURORA_ENDPOINT = split(":", aws_rds_cluster.aurora_cluster.endpoint)[0]
    AURORA_USER     = "postgres"
    AURORA_PASSWORD = random_password.aurora_password.result
    AURORA_PORT     = 5432
    RDS_ENDPOINT    = split(":", aws_db_instance.postgres_rds.endpoint)[0]
    RDS_USER        = "postgres"
    RDS_PASSWORD    = random_password.postgres_password.result
    RDS_PORT        = 5432
  })

  # ----------------------------------------------------------------------------
  # TAGS
  # ----------------------------------------------------------------------------
  # Identifies the pgweb instance for operations and cost tracking.
  # ----------------------------------------------------------------------------
  tags = {
    Name = "pgweb-deployment"
  }

  # Ensure the read replica exists before provisioning pgweb
  depends_on = [aws_db_instance.postgres_rds_replica]
}
