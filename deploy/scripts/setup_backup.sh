#!/bin/bash
set -e

LOG_FILE="/home/ubuntu/setup_backup.log"
exec > "$LOG_FILE" 2>&1

echo "Setting up S3 backup cron job..."

# Ensure audit directory exists
mkdir -p /var/mlops/audit

CRON_JOB="0 2 * * * aws s3 sync /var/mlops/audit s3://mlops-audit-backups/audit"

# Load existing crontab safely
crontab -l 2>/dev/null > /tmp/current_cron || true

# Add cron job only if not present
if ! grep -Fxq "$CRON_JOB" /tmp/current_cron; then
    echo "$CRON_JOB" >> /tmp/current_cron
    crontab /tmp/current_cron
    echo "Cron job added."
else
    echo "Cron job already exists."
fi

rm -f /tmp/current_cron

echo "S3 backup cron job setup completed."
