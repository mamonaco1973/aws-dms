#!/bin/bash
# ==============================================================================
# FILE: install_pgweb.sh
# ==============================================================================
# ORCHESTRATION SCRIPT: PGWEB INSTALL
# ==============================================================================
# Installs and configures pgweb as a systemd-managed web UI for PostgreSQL.
# The PostgreSQL RDS instance starts empty — DMS populates it with Sakila data
# during the migration task in Phase 2.
#
# High-level flow:
#   1) Install required packages (postgresql-client, unzip).
#   2) Install pgweb binary.
#   3) Register pgweb as a systemd service on port 80.
#
# Notes:
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