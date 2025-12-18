#!/bin/bash
set -e

LOG_FILE="/home/ubuntu/setup_backup.log"
exec > "$LOG_FILE" 2>&1

echo "==== setup_backup.sh (AfterInstall) ===="
date
echo "Running as user: $(whoami)"
echo "PWD: $(pwd)"

# ============================================
# 1. CREATE AND CONFIGURE AUDIT DIRECTORY
# ============================================
echo "Creating audit directory..."
sudo mkdir -p /var/mlops/audit
sudo chown -R ubuntu:ubuntu /var/mlops/audit
sudo chmod -R 755 /var/mlops/audit
echo "✓ Audit directory created at /var/mlops/audit"

# ============================================
# 2. SETUP CRON JOB FOR S3 BACKUP
# ============================================
# Find aws CLI
AWS_BIN="$(command -v aws || true)"
if [ -z "$AWS_BIN" ]; then
  echo "ERROR: aws CLI not found in PATH"
  exit 1
fi
echo "✓ AWS CLI found at: $AWS_BIN"
"$AWS_BIN" --version

# Build cron line with full path and its own logging
CRON_JOB="0 2 * * * $AWS_BIN s3 sync /var/mlops/audit s3://mlops-audit-backups/audit >> /home/ubuntu/s3_sync.log 2>&1"

# Load existing crontab (do not let failure kill script)
crontab -l 2>/dev/null > /tmp/current_cron || touch /tmp/current_cron

# Append job if missing
if ! grep -Fq "s3 sync /var/mlops/audit s3://mlops-audit-backups/audit" /tmp/current_cron; then
    echo "$CRON_JOB" >> /tmp/current_cron
    if crontab /tmp/current_cron; then
        echo "✓ Cron job added successfully"
    else
        echo "ERROR: failed to install crontab for ubuntu"
        rm -f /tmp/current_cron
        exit 1
    fi
else
    echo "✓ Cron job already exists"
fi

rm -f /tmp/current_cron

# Verify cron job was added
echo "Current crontab for ubuntu:"
crontab -l

echo ""
echo "==== setup_backup.sh completed successfully ===="