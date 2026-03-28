#!/bin/bash
# ==============================================================================
# FILE: destroy.sh
# ==============================================================================
# ORCHESTRATION SCRIPT: RDS TEARDOWN
# ==============================================================================
# Destroys all RDS-related infrastructure provisioned by Terraform.
#
# High-level flow:
#   1) Set the AWS default region for CLI and Terraform.
#   2) Initialize Terraform in the RDS workspace.
#   3) Destroy all managed RDS resources non-interactively.
#
# Notes:
# - This script assumes the infrastructure was created via Terraform.
# - Resources are destroyed without confirmation using auto-approve.
# ==============================================================================

# ==============================================================================
# SET AWS DEFAULT REGION
# ==============================================================================
# Export the AWS region used by Terraform and AWS CLI commands.
# ==============================================================================
export AWS_DEFAULT_REGION="us-east-2"

# ==============================================================================
# STEP 1: DESTROY RDS INFRASTRUCTURE
# ==============================================================================
# Tear down all RDS and related resources managed by Terraform.
# ==============================================================================

# Change into the Terraform working directory.
cd 01-rds

# Initialize Terraform backend and providers.
terraform init

# Destroy Terraform-managed resources non-interactively.
terraform destroy -auto-approve

# Return to the project root directory.
cd ..
