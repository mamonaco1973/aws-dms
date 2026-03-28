#!/bin/bash
# ==============================================================================
# FILE: check_env.sh
# ==============================================================================
# ENVIRONMENT VALIDATION SCRIPT
# ==============================================================================
# Validates that all required CLI tools are available in the PATH and that
# AWS credentials are configured correctly before running Terraform.
#
# High-level flow:
#   1) Verify required commands exist in PATH.
#   2) Fail fast if any command is missing.
#   3) Validate AWS CLI authentication using STS.
#
# Notes:
# - This script is intentionally verbose to aid troubleshooting.
# - Any failure causes the script to exit with a non-zero status.
# ==============================================================================

echo "NOTE: Validating that required commands are found in your PATH."

# ------------------------------------------------------------------------------
# REQUIRED COMMAND CHECK
# ------------------------------------------------------------------------------
# List of commands required for this project to function correctly.
# ------------------------------------------------------------------------------

commands=("aws" "terraform" "jq")

# Flag indicating whether all required commands were found
all_found=true

# Iterate through required commands and verify availability
for cmd in "${commands[@]}"; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "ERROR: $cmd is not found in the current PATH."
    all_found=false
  else
    echo "NOTE: $cmd is found in the current PATH."
  fi
done

# ------------------------------------------------------------------------------
# COMMAND VALIDATION RESULT
# ------------------------------------------------------------------------------
# Abort execution if any required command is missing.
# ------------------------------------------------------------------------------

if [ "$all_found" = true ]; then
  echo "NOTE: All required commands are available."
else
  echo "ERROR: One or more required commands are missing."
  exit 1
fi

# ------------------------------------------------------------------------------
# AWS AUTHENTICATION CHECK
# ------------------------------------------------------------------------------
# Validate AWS CLI authentication using STS.
# ------------------------------------------------------------------------------

echo "NOTE: Checking AWS CLI connection."

aws sts get-caller-identity --query "Account" --output text >> /dev/null

# Abort execution if AWS authentication fails.
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to connect to AWS."
  echo "ERROR: Check credentials and environment variables."
  exit 1
else
  echo "NOTE: Successfully authenticated to AWS."
fi
