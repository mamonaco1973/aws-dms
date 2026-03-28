# ===============================================================================
# AWS PROVIDER CONFIGURATION
# ===============================================================================
# Configures the AWS provider used by Terraform to authenticate and
# manage AWS resources defined in this configuration.
#
# The region setting determines where all AWS resources are created.
# Selecting the wrong region can increase latency, cost, or violate
# compliance requirements.
#
# Notes:
# - AWS credentials must be configured outside of Terraform.
# - Supported methods include AWS CLI config, environment variables,
#   or IAM roles when running on AWS infrastructure.
# - Update the region value if deploying outside us-east-2.
# ===============================================================================

provider "aws" {

  # AWS region where resources will be provisioned
  region = "us-east-2"
}
