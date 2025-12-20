#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

echo "Updating system..."
apt-get update -y

echo "Installing prerequisites..."
apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  cron \
  unzip

# -----------------------------
# Add Docker official GPG key
# -----------------------------
echo "Adding Docker GPG key..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# -----------------------------
# Add Docker repository
# -----------------------------
echo "Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  noble stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y

# -----------------------------
# Install Docker + Compose
# -----------------------------
echo "Installing Docker Engine and Compose plugin..."
apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# -----------------------------
# Enable services
# -----------------------------
echo "Enabling Docker and cron..."
systemctl enable docker
systemctl start docker
systemctl enable cron
systemctl start cron

# -----------------------------
# AWS CLI (idempotent)
# -----------------------------
if ! command -v aws >/dev/null 2>&1; then
  echo "Installing AWS CLI..."
  curl -s https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install
  rm -rf /tmp/aws /tmp/awscliv2.zip
else
  echo "AWS CLI already installed"
fi

# -----------------------------
# Docker permissions
# -----------------------------
echo "Adding ubuntu user to docker group..."
usermod -aG docker ubuntu

# -----------------------------
# Audit directory
# -----------------------------
echo "Creating audit directory..."
mkdir -p /var/mlops/audit
chown -R ubuntu:ubuntu /var/mlops/audit
chmod 755 /var/mlops/audit

echo "install_dependencies.sh completed successfully"
