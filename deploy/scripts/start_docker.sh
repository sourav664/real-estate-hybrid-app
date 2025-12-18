#!/bin/bash
# Log everything to start_docker.log
exec > /home/ubuntu/start_docker.log 2>&1

echo "===== ApplicationStart: start_docker.sh ====="

export PATH=/usr/local/bin:/usr/bin:/bin

cd /home/ubuntu/app || exit 1

echo "Logging in to ECR..."
aws ecr get-login-password --region ap-south-1 \
  | docker login --username AWS --password-stdin 957417441966.dkr.ecr.ap-south-1.amazonaws.com

echo "Pulling latest Docker image..."
docker compose pull

echo "Stopping existing containers..."
docker compose down || true

echo "Starting containers..."
docker compose up -d

echo "Application started successfully."
