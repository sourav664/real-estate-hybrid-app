#!/bin/bash
exec > /home/ubuntu/start_docker.log 2>&1

cd /home/ubuntu/app || exit 1

# Create audit directory with proper ownership
sudo mkdir -p /var/mlops/audit
sudo chown -R ubuntu:ubuntu /var/mlops/audit

# Check if .env exists
if [ ! -f .env ]; then
    echo "ERROR: .env file not found!"
    exit 1
fi

# ECR login
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 957417441966.dkr.ecr.ap-south-1.amazonaws.com

# Pull latest image
docker pull 957417441966.dkr.ecr.ap-south-1.amazonaws.com/real-estate-streamlit:latest

# Stop and remove old containers
docker compose down || true

# Start new containers
docker compose up -d

# Verify container is running
sleep 5
docker ps | grep real-estate || echo "WARNING: Container may not be running!"