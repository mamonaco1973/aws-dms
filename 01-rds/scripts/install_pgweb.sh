#!/bin/bash
# ==============================================================================
# FILE: install_pgweb.sh
# ==============================================================================
# ORCHESTRATION SCRIPT: PAGILA LOAD AND PGWEB INSTALL
# ==============================================================================
# Loads the Pagila sample database into Aurora and RDS PostgreSQL instances,
# then installs and configures pgweb as a systemd-managed web UI.
#
# High-level flow:
#   1) Install required packages (psql client, unzip).
#   2) Clone repo containing Pagila SQL scripts.
#   3) Load Pagila into Aurora using provided credentials and endpoint.
#   4) Load Pagila into RDS using provided credentials and endpoint.
#   5) Install pgweb and register a systemd service on port 80.
#
# Notes:
# - Assumes AURORA_* and RDS_* environment variables are already defined.
# - Pagila load output is appended to /root/db_load.log.
# - pgweb is configured to listen on all interfaces (0.0.0.0).
# ==============================================================================

# ------------------------------------------------------------------------------
# UPDATE AND INSTALL DEPENDENCIES
# ------------------------------------------------------------------------------
# Update package metadata and install tools required for database load and
# pgweb installation.
# ------------------------------------------------------------------------------

apt update -y
apt install -y postgresql-client unzip

# ------------------------------------------------------------------------------
# CLONE REPO CONTAINING PAGILA SQL FILES
# ------------------------------------------------------------------------------
# Pull the Pagila SQL artifacts from GitHub into a temporary workspace.
# ------------------------------------------------------------------------------

cd /tmp
git clone https://github.com/mamonaco1973/aws-postgres.git
cd aws-postgres/01-rds/data

# ------------------------------------------------------------------------------
# SET ENVIRONMENT VARIABLES FOR AURORA
# ------------------------------------------------------------------------------
# Configure PostgreSQL client variables for the Aurora endpoint.
# ------------------------------------------------------------------------------

export PGPASSWORD="${AURORA_PASSWORD}"
export PGUSER="${AURORA_USER}"
export PGENDPOINT="${AURORA_ENDPOINT}"

# ------------------------------------------------------------------------------
# LOAD PAGILA INTO AURORA
# ------------------------------------------------------------------------------
# Load the database, schema, and data into Aurora. All output is logged.
# ------------------------------------------------------------------------------
echo "NOTE: Loading Aurora Test Database..." >> /root/db_load.log 2>&1

PGPASSWORD=$PGPASSWORD psql -h $PGENDPOINT -U postgres -d postgres \
  -f pagila-db.sql >> /root/db_load.log 2>&1

PGPASSWORD=$PGPASSWORD psql -h $PGENDPOINT -U postgres -d pagila \
  -f pagila-schema.sql >> /root/db_load.log 2>&1

PGPASSWORD=$PGPASSWORD psql -h $PGENDPOINT -U postgres -d pagila \
  -f pagila-data.sql >> /root/db_load.log 2>&1

# ------------------------------------------------------------------------------
# SET ENVIRONMENT VARIABLES FOR RDS
# ------------------------------------------------------------------------------
# Configure PostgreSQL client variables for the standalone RDS endpoint.
# ------------------------------------------------------------------------------

export PGPASSWORD="${RDS_PASSWORD}"
export PGUSER="${RDS_USER}"
export PGENDPOINT="${RDS_ENDPOINT}"

# ------------------------------------------------------------------------------
# LOAD PAGILA INTO RDS
# ------------------------------------------------------------------------------
# Load the database, schema, and data into standalone RDS. All output is logged.
# ------------------------------------------------------------------------------

echo "NOTE: Loading RDS Test Database..." >> /root/db_load.log 2>&1

PGPASSWORD=$PGPASSWORD psql -h $PGENDPOINT -U postgres -d postgres \
  -f pagila-db.sql >> /root/db_load.log 2>&1

PGPASSWORD=$PGPASSWORD psql -h $PGENDPOINT -U postgres -d pagila \
  -f pagila-schema.sql >> /root/db_load.log 2>&1

PGPASSWORD=$PGPASSWORD psql -h $PGENDPOINT -U postgres -d pagila \
  -f pagila-data.sql >> /root/db_load.log 2>&1

# ------------------------------------------------------------------------------
# INSTALL AND CONFIGURE PGWEB
# ------------------------------------------------------------------------------
# Download and install pgweb, then configure it to run as a systemd service.
# ------------------------------------------------------------------------------

cd /tmp
wget https://github.com/sosedoff/pgweb/releases/download/v0.11.12/pgweb_linux_amd64.zip
unzip pgweb_linux_amd64.zip >> /root/pgweb.log 2>&1
chmod +x pgweb_linux_amd64
sudo mv pgweb_linux_amd64 /usr/local/bin/pgweb

# ------------------------------------------------------------------------------
# PGWEB CONFIGURATION
# ------------------------------------------------------------------------------
# Define runtime settings for the pgweb systemd service.
# ------------------------------------------------------------------------------

PGWEB_BIN="/usr/local/bin/pgweb"
PGWEB_USER="root"
PGWEB_HOME="/root"
PGWEB_PORT="80"

# ------------------------------------------------------------------------------
# VERIFY PGWEB INSTALLATION
# ------------------------------------------------------------------------------
# Abort early if the pgweb binary is not present where expected.
# ------------------------------------------------------------------------------

if [ ! -f "$PGWEB_BIN" ]; then
  echo "Error: $PGWEB_BIN not found"
  exit 1
fi

# ------------------------------------------------------------------------------
# CREATE SYSTEMD UNIT FILE
# ------------------------------------------------------------------------------
# Configure pgweb to bind to all interfaces and listen on the chosen port.
# ------------------------------------------------------------------------------

cat <<EOF > /etc/systemd/system/pgweb.service
[Unit]
Description=Pgweb - Web UI for PostgreSQL
After=network.target

[Service]
Type=simple
ExecStart=$PGWEB_BIN --listen=$PGWEB_PORT --bind 0.0.0.0
Restart=on-failure
User=$PGWEB_USER
WorkingDirectory=$PGWEB_HOME

[Install]
WantedBy=multi-user.target
EOF

# ------------------------------------------------------------------------------
# ENABLE AND START PGWEB SERVICE
# ------------------------------------------------------------------------------
# Reload systemd units, enable pgweb at boot, and start it immediately.
# ------------------------------------------------------------------------------

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable pgweb
systemctl start pgweb
systemctl status pgweb | cat >> /root/pgweb.log 2>&1