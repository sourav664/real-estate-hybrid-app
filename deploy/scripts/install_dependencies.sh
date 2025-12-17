#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

echo "Updating system..."
apt-get update -y

echo "Installing base packages..."
apt-get install -y docker.io unzip curl cron

echo "Starting services..."
systemctl start docker
systemctl enable docker
systemctl start cron
systemctl enable cron

# Install AWS CLI only if not installed
if ! command -v aws >/dev/null 2>&1; then
  echo "Installing AWS CLI..."
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  unzip -o /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install
else
  echo "AWS CLI already installed, skipping."
fi

echo "Adding ubuntu user to docker group..."
usermod -aG docker ubuntu

echo "install_dependencies.sh completed successfully"
