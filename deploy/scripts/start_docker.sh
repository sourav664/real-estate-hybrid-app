#!/bin/bash
set -e

LOG_FILE="/home/ubuntu/start_docker.log"
exec > "$LOG_FILE" 2>&1

echo "==== start_docker.sh (ApplicationStart) ===="
date
echo "Running as user: $(whoami)"
echo "Groups: $(groups)"
echo "PWD: $(pwd)"

# Navigate to app directory
cd /home/ubuntu/app || {
    echo "ERROR: Cannot change to /home/ubuntu/app"
    exit 1
}

echo "Current directory: $(pwd)"
echo "Directory contents:"
ls -la

# Create audit directory with proper ownership
# sudo mkdir -p /var/mlops/audit
# sudo chown -R ubuntu:ubuntu /var/mlops/audit
# echo "Audit directory created and permissions set"

# Check if .env exists
if [ ! -f .env ]; then
    echo "ERROR: .env file not found in $(pwd)"
    echo "Files in current directory:"
    ls -la
    exit 1
fi
echo ".env file found"

# Check if compose.yaml exists
if [ ! -f compose.yaml ] && [ ! -f docker-compose.yaml ] && [ ! -f docker-compose.yml ]; then
    echo "ERROR: No compose file found"
    echo "Files in current directory:"
    ls -la
    exit 1
fi
echo "Compose file found"

# Wait for docker socket to be accessible
echo "Waiting for Docker socket..."
for i in {1..30}; do
    if docker ps >/dev/null 2>&1; then
        echo "Docker is accessible"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "ERROR: Docker is not accessible after 30 seconds"
        echo "Trying with newgrp docker..."
        exec sg docker -c "$0 $*"
    fi
    echo "Waiting for Docker... attempt $i/30"
    sleep 1
done

# Verify docker works
echo "Testing docker command..."
docker --version || {
    echo "ERROR: docker command failed"
    exit 1
}

echo "Checking docker daemon..."
docker ps || {
    echo "ERROR: Cannot connect to docker daemon"
    echo "Retrying with newgrp..."
    exec sg docker -c "$0 $*"
}

# ECR login
echo "Logging into ECR..."
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 957417441966.dkr.ecr.ap-south-1.amazonaws.com || {
    echo "ERROR: ECR login failed"
    exit 1
}

# Pull latest image
echo "Pulling latest image..."
docker pull 957417441966.dkr.ecr.ap-south-1.amazonaws.com/real-estate-streamlit:latest || {
    echo "ERROR: Docker pull failed"
    exit 1
}

# Stop and remove old containers
echo "Stopping old containers..."
docker compose down 2>&1 || echo "No existing containers to stop"

# Start new containers
echo "Starting new containers..."
docker compose up -d || {
    echo "ERROR: docker compose up failed"
    exit 1
}

# Verify container is running
echo "Waiting for container to start..."
sleep 5

echo "Checking running containers..."
docker ps

if docker ps | grep -q real-estate; then
    echo "SUCCESS: Container is running"
else
    echo "WARNING: Container may not be running"
    echo "Container logs:"
    docker logs real-estate 2>&1 || echo "Could not fetch logs"
fi

echo "start_docker.sh completed successfully"#!/bin/bash

LOG_FILE="/home/ubuntu/start_docker.log"
exec > "$LOG_FILE" 2>&1

echo "==== start_docker.sh (ApplicationStart) ===="
date
echo "Running as user: $(whoami)"
echo "PWD: $(pwd)"

# ============================================
# 1. NAVIGATE TO APP DIRECTORY
# ============================================
cd /home/ubuntu/app || {
    echo "ERROR: Cannot change to /home/ubuntu/app"
    ls -la /home/ubuntu/ || true
    exit 1
}

echo "Current directory: $(pwd)"
echo "Directory contents:"
ls -la

# ============================================
# 2. VERIFY AUDIT DIRECTORY EXISTS
# ============================================
if [ ! -d /var/mlops/audit ]; then
    echo "ERROR: Audit directory doesn't exist. setup_backup.sh may have failed."
    exit 1
fi
echo "✓ Audit directory exists"

# ============================================
# 3. CHECK REQUIRED FILES
# ============================================
echo "Checking for required files..."

if [ ! -f compose.yaml ] && [ ! -f docker-compose.yaml ] && [ ! -f docker-compose.yml ]; then
    echo "ERROR: No compose file found!"
    echo "Files present:"
    ls -la
    exit 1
fi
echo "✓ Compose file found"

if [ ! -f .env ]; then
    echo "WARNING: .env file not found, creating empty one"
    touch .env
fi
echo "✓ .env file present"

# ============================================
# 4. VERIFY DOCKER IS RUNNING
# ============================================
echo "Checking Docker daemon..."
if ! systemctl is-active --quiet docker; then
    echo "Docker daemon not running, starting..."
    systemctl start docker
    sleep 3
fi

if docker info >/dev/null 2>&1; then
    echo "✓ Docker daemon is running"
else
    echo "ERROR: Docker daemon is not accessible"
    systemctl status docker || true
    exit 1
fi

# ============================================
# 5. VERIFY AWS CLI AND CREDENTIALS
# ============================================
echo "Checking AWS CLI..."
if ! command -v aws >/dev/null 2>&1; then
    echo "ERROR: AWS CLI not found"
    exit 1
fi
echo "✓ AWS CLI found: $(which aws)"

echo "Testing AWS credentials..."
if aws sts get-caller-identity >/dev/null 2>&1; then
    echo "✓ AWS credentials working"
    aws sts get-caller-identity
else
    echo "ERROR: AWS credentials not working"
    echo "This EC2 instance needs an IAM role with ECR permissions"
    exit 1
fi

# ============================================
# 6. LOGIN TO ECR
# ============================================
echo "Logging into ECR..."
AWS_REGION="ap-south-1"
ECR_REGISTRY="957417441966.dkr.ecr.ap-south-1.amazonaws.com"

if aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"; then
    echo "✓ ECR login successful"
else
    echo "ERROR: ECR login failed"
    echo "Make sure the EC2 instance has an IAM role with ECR permissions"
    exit 1
fi

# ============================================
# 7. PULL LATEST IMAGE
# ============================================
echo "Pulling latest image..."
IMAGE="${ECR_REGISTRY}/real-estate-streamlit:latest"
if docker pull "$IMAGE"; then
    echo "✓ Image pulled successfully"
else
    echo "ERROR: Failed to pull image"
    echo "Check if the image exists in ECR:"
    aws ecr describe-images --repository-name real-estate-streamlit --region "$AWS_REGION" || true
    exit 1
fi

# ============================================
# 8. STOP OLD CONTAINERS
# ============================================
echo "Stopping old containers..."
docker compose down 2>&1 || echo "No existing containers to stop"

# Clean up old containers
echo "Cleaning up old containers..."
docker container prune -f || true

# ============================================
# 9. START NEW CONTAINERS
# ============================================
echo "Starting containers with docker compose..."
if docker compose up -d; then
    echo "✓ Containers started successfully"
else
    echo "ERROR: Failed to start containers"
    echo "Compose file contents:"
    cat compose.yaml || cat docker-compose.yaml || cat docker-compose.yml || true
    exit 1
fi

# ============================================
# 10. VERIFY DEPLOYMENT
# ============================================
echo "Waiting for container to be ready..."
sleep 5

echo "Checking container status..."
docker ps -a

if docker ps | grep -q real-estate; then
    echo "✓ Container 'real-estate' is running"
    
    echo ""
    echo "Container logs (last 20 lines):"
    docker logs --tail 20 real-estate
    
    echo ""
    echo "==== DEPLOYMENT SUCCESSFUL ===="
    exit 0
else
    echo "ERROR: Container 'real-estate' is not running"
    echo ""
    echo "All containers:"
    docker ps -a
    echo ""
    echo "Trying to get logs from stopped container:"
    docker logs real-estate 2>&1 || echo "Could not fetch logs"
    exit 1
fi