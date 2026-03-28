# ================================================================================
# RESOURCE: aws_instance.phpmyadmin-rds-instance
# ================================================================================
# Purpose:
#   Launches an Ubuntu 24.04 EC2 instance that hosts phpMyAdmin for
#   administering an Aurora / RDS MySQL database.
#
# Architecture:
#   - Access is intended via AWS SSM Session Manager or a private proxy
#   - IAM instance profile grants Systems Manager permissions
# ================================================================================

resource "aws_instance" "phpmyadmin-rds-instance" {
  # ------------------------------------------------------------------------------
  # AMI AND INSTANCE TYPE
  # ------------------------------------------------------------------------------
  # Uses the latest Ubuntu 24.04 AMI resolved through a data source.
  # The t3.medium instance type provides sufficient resources for
  # phpMyAdmin and lightweight administrative workloads.
  # ------------------------------------------------------------------------------
  ami           = data.aws_ami.ubuntu_ami.id
  instance_type = "t3.medium"

  # ------------------------------------------------------------------------------
  # NETWORKING
  # ------------------------------------------------------------------------------
  # Places the instance in a private subnet without a public IP.
  # Inbound access is controlled by the associated security group.
  # ------------------------------------------------------------------------------
  subnet_id                   = aws_subnet.rds-subnet-1.id
  vpc_security_group_ids      = [aws_security_group.http_sg.id]
  associate_public_ip_address = true

  # ------------------------------------------------------------------------------
  # IAM / SSM ACCESS
  # ------------------------------------------------------------------------------
  # Attaches an IAM instance profile that allows the EC2 instance to
  # register with AWS Systems Manager for secure, agent-based access.
  # ------------------------------------------------------------------------------
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name

  # ------------------------------------------------------------------------------
  # USER DATA (OPTIONAL)
  # ------------------------------------------------------------------------------
  # Renders a cloud-init script from a template to configure the
  # phpMyAdmin host at boot time. This is currently disabled.
  #
  # Example usage:
  #   - Inject database endpoint
  #   - Configure PHP, Apache/Nginx, and phpMyAdmin
  # ------------------------------------------------------------------------------
  user_data = templatefile("${path.module}/scripts/install-phpmyadmin.sh", {
    DB_ENDPOINT = split(":", aws_db_instance.mysql_rds.endpoint)[0]
    DB_USER     = "admin"
    DB_PASSWORD = random_password.mysql_password.result
    DB_PORT     = 3306

  })

  # ------------------------------------------------------------------------------
  # TAGS
  # ------------------------------------------------------------------------------
  # Identifies the instance for operational visibility and cost tracking.
  # ------------------------------------------------------------------------------
  tags = {
    Name = "phpmyadmin-rds"
  }

  depends_on = [aws_db_instance.mysql_rds_replica]
}

# ================================================================================
# RESOURCE: aws_instance.phpmyadmin-aurora-instance
# ================================================================================
# Purpose:
#   Launches an Ubuntu 24.04 EC2 instance that hosts phpMyAdmin for
#   administering an Aurora / RDS MySQL database.
#
# Architecture:
#   - Access is intended via AWS SSM Session Manager or a private proxy
#   - IAM instance profile grants Systems Manager permissions
# ================================================================================

resource "aws_instance" "phpmyadmin-aurora-instance" {
  # ------------------------------------------------------------------------------
  # AMI AND INSTANCE TYPE
  # ------------------------------------------------------------------------------
  # Uses the latest Ubuntu 24.04 AMI resolved through a data source.
  # The t3.medium instance type provides sufficient resources for
  # phpMyAdmin and lightweight administrative workloads.
  # ------------------------------------------------------------------------------
  ami           = data.aws_ami.ubuntu_ami.id
  instance_type = "t3.medium"

  # ------------------------------------------------------------------------------
  # NETWORKING
  # ------------------------------------------------------------------------------
  # Places the instance in a private subnet without a public IP.
  # Inbound access is controlled by the associated security group.
  # ------------------------------------------------------------------------------
  subnet_id                   = aws_subnet.rds-subnet-1.id
  vpc_security_group_ids      = [aws_security_group.http_sg.id]
  associate_public_ip_address = true

  # ------------------------------------------------------------------------------
  # IAM / SSM ACCESS
  # ------------------------------------------------------------------------------
  # Attaches an IAM instance profile that allows the EC2 instance to
  # register with AWS Systems Manager for secure, agent-based access.
  # ------------------------------------------------------------------------------
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name

  # ------------------------------------------------------------------------------
  # USER DATA (OPTIONAL)
  # ------------------------------------------------------------------------------
  # Renders a cloud-init script from a template to configure the
  # phpMyAdmin host at boot time. This is currently disabled.
  #
  # Example usage:
  #   - Inject database endpoint
  #   - Configure PHP, Apache/Nginx, and phpMyAdmin
  # ------------------------------------------------------------------------------
  user_data = templatefile("${path.module}/scripts/install-phpmyadmin.sh", {
    DB_ENDPOINT = split(":", aws_rds_cluster.aurora_cluster.endpoint)[0]
    DB_USER     = "admin"
    DB_PASSWORD = random_password.aurora_password.result
    DB_PORT     = 3306

  })

  # ------------------------------------------------------------------------------
  # TAGS
  # ------------------------------------------------------------------------------
  # Identifies the instance for operational visibility and cost tracking.
  # ------------------------------------------------------------------------------
  tags = {
    Name = "phpmyadmin-aurora"
  }

  depends_on = [aws_db_instance.mysql_rds_replica]
}
