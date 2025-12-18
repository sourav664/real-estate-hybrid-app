#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

echo "Updating system..."
apt-get update -y

echo "Installing base packages..."
apt-get install -y docker.io docker-compose-plugin unzip curl cron

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
  rm -rf /tmp/awscliv2.zip /tmp/aws
  echo "✓ AWS CLI installed"
else
  echo "✓ AWS CLI already installed"
  aws --version
fi

echo "Adding ubuntu user to docker group..."
usermod -aG docker ubuntu

# Ensure docker socket has correct permissions
chmod 666 /var/run/docker.sock

# Verify docker compose plugin is available
echo "Verifying Docker Compose plugin..."
if docker compose version >/dev/null 2>&1; then
    echo "✓ Docker Compose plugin installed"
    docker compose version
else
    echo "ERROR: Docker Compose plugin not available"
    exit 1
fi

# Verify ubuntu user can access docker
echo "Verifying docker access for ubuntu user..."
su - ubuntu -c "docker ps" && echo "✓ Ubuntu user can access Docker" || {
    echo "WARNING: ubuntu user cannot access docker yet, but should work after relogin"
}

echo ""
echo "==== install_dependencies.sh completed successfully ===="