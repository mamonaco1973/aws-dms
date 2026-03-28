#!/bin/bash
# ==============================================================================
# FILE: validate.sh
# ==============================================================================
# PURPOSE:
#   Resolves and prints the public pgweb endpoint for an EC2 instance
#   providing a lightweight web UI for PostgreSQL database access.
#
# WHAT THIS SCRIPT DOES:
#   1) Looks up a running EC2 instance by its Name tag.
#   2) Extracts the instance's PublicDnsName.
#   3) Fails fast if the instance has no public DNS (or is not found).
#   4) Prints the resulting pgweb URL for quick validation.
#
# PREREQUISITES:
#   - AWS CLI installed and configured with permissions for ec2:DescribeInstances
#   - The target EC2 instance exists, is running, and has a public DNS name
#     (i.e., it is in a public subnet with a public IPv4 / EIP).
#
# NOTES:
#   - This script assumes pgweb is served from the web root ("/").
#   - If multiple instances share the same Name tag, the first match is used.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# CONFIG
# ------------------------------------------------------------------------------
# AWS region where the pgweb EC2 instance is running.
AWS_REGION="us-east-2"

# ------------------------------------------------------------------------------
# RESOLVE PGWEB ENDPOINT
# ------------------------------------------------------------------------------
# Expected EC2 Name tag value for the pgweb host.
PGWEB_INSTANCE_NAME="pgweb-deployment"

# ------------------------------------------------------------------------------
# FUNCTION: get_public_dns
# ------------------------------------------------------------------------------
# Returns the public DNS name for the first running EC2 instance whose Name tag
# matches the provided value.
#
# Args:
#   $1: instance_name  (value of the Name tag)
#
# Output:
#   Writes the PublicDnsName to stdout (or "None" if not present).
get_public_dns() {
  local instance_name="$1"

  aws ec2 describe-instances \
    --region "${AWS_REGION}" \
    --filters \
      "Name=tag:Name,Values=${instance_name}" \
      "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].PublicDnsName' \
    --output text
}

# Resolve public DNS name for the pgweb host.
PGWEB_PUBLIC_DNS=$(get_public_dns "${PGWEB_INSTANCE_NAME}")

# ------------------------------------------------------------------------------
# VALIDATION
# ------------------------------------------------------------------------------
# Fail fast if the instance is missing a public DNS name (not found, stopped,
# or running without a public interface).
if [[ -z "${PGWEB_PUBLIC_DNS}" || "${PGWEB_PUBLIC_DNS}" == "None" ]]; then
  echo "ERROR: ${PGWEB_INSTANCE_NAME} has no public DNS name"
  exit 1
fi

# ------------------------------------------------------------------------------
# DATABASE ENDPOINT RESOLUTION
# ------------------------------------------------------------------------------
# Resolve database connection endpoints used by pgweb.
#
# These endpoints are NOT required for pgweb to start, but are printed for
# convenience so the operator can easily copy/paste them when connecting
# pgweb to either backend.
#
# Both endpoints are resolved dynamically from AWS to avoid hardcoding
# DNS names that may change across environments.
# ------------------------------------------------------------------------------

# Aurora PostgreSQL cluster identifier (Terraform-managed)
# This should match the aws_rds_cluster identifier exactly.
CLUSTER_ID="aurora-postgres-cluster"

# Resolve the Aurora PostgreSQL writer endpoint.
# pgweb should always connect to the writer endpoint when targeting Aurora.
AURORA_ENDPOINT=$(aws rds describe-db-clusters \
  --region "${AWS_REGION}" \
  --db-cluster-identifier "${CLUSTER_ID}" \
  --query 'DBClusters[0].Endpoint' \
  --output text)

# Resolve the standalone RDS PostgreSQL instance endpoint.
# This is the primary connection address for the RDS-backed deployment.
RDS_ENDPOINT=$(aws rds describe-db-instances \
  --region "${AWS_REGION}" \
  --db-instance-identifier "postgres-rds-instance" \
  --query "DBInstances[0].Endpoint.Address" \
  --output text)

# ------------------------------------------------------------------------------
# DISPLAY RESULTS
# ------------------------------------------------------------------------------

echo "=========================================================================="
echo " PROJECT ENDPOINTS"
echo "=========================================================================="
echo
echo " PGWEB Application:"
echo "   http://${PGWEB_PUBLIC_DNS}"
echo
echo " RDS Instance:"
echo "   ${RDS_ENDPOINT}"
echo
echo " Aurora Instance:"
echo "   ${AURORA_ENDPOINT}"
echo
echo "=========================================================================="
