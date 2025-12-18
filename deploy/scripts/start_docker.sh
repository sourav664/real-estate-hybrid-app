#!/bin/bash
set -e

# ============================================
# CONFIGURATION
# ============================================
LOG_FILE="/home/ubuntu/start_docker.log"
APP_DIR="/home/ubuntu/app"
AWS_REGION="ap-south-1"
ECR_REGISTRY="957417441966.dkr.ecr.ap-south-1.amazonaws.com"
ECR_REPO="real-estate-streamlit"
CONTAINER_NAME="real-estate"

# Redirect all output to log file
exec > "$LOG_FILE" 2>&1

echo "=========================================="
echo "   ApplicationStart - start_docker.sh"
echo "=========================================="
date
echo "User: $(whoami)"
echo "Groups: $(groups)"
echo "Shell: $SHELL"
echo ""

# ============================================
# 1. NAVIGATE TO APP DIRECTORY
# ============================================
echo "[1/11] Navigating to app directory..."
if [ ! -d "$APP_DIR" ]; then
    echo "ERROR: Directory $APP_DIR does not exist"
    echo "Contents of /home/ubuntu/:"
    ls -la /home/ubuntu/ || true
    exit 1
fi

cd "$APP_DIR" || {
    echo "ERROR: Cannot change to $APP_DIR"
    exit 1
}
echo "✓ Current directory: $(pwd)"
echo "Contents:"
ls -la
echo ""

# ============================================
# 2. VERIFY COMPOSE FILE EXISTS
# ============================================
echo "[2/11] Checking for Docker Compose file..."
COMPOSE_FILE=""
if [ -f "compose.yaml" ]; then
    COMPOSE_FILE="compose.yaml"
elif [ -f "docker-compose.yaml" ]; then
    COMPOSE_FILE="docker-compose.yaml"
elif [ -f "docker-compose.yml" ]; then
    COMPOSE_FILE="docker-compose.yml"
else
    echo "ERROR: No Docker Compose file found"
    echo "Files in current directory:"
    ls -la
    exit 1
fi
echo "✓ Found: $COMPOSE_FILE"
echo ""

# ============================================
# 3. CHECK/CREATE .env FILE
# ============================================
echo "[3/11] Checking .env file..."
if [ ! -f .env ]; then
    echo "WARNING: .env file not found, creating empty one"
    touch .env
    chmod 600 .env
fi
echo "✓ .env file present"
echo ""

# ============================================
# 4. CREATE/VERIFY AUDIT DIRECTORY (OPTIONAL)
# ============================================
echo "[4/11] Setting up audit directory..."
AUDIT_DIR="/var/mlops/audit"
if [ ! -d "$AUDIT_DIR" ]; then
    echo "Creating audit directory at $AUDIT_DIR"
    sudo mkdir -p "$AUDIT_DIR"
    sudo chown -R ubuntu:ubuntu "$AUDIT_DIR"
    echo "✓ Audit directory created"
else
    echo "✓ Audit directory exists"
fi
echo ""

# ============================================
# 5. VERIFY DOCKER IS INSTALLED
# ============================================
echo "[5/11] Checking Docker installation..."
if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker is not installed"
    exit 1
fi
echo "✓ Docker version: $(docker --version)"
echo ""

# ============================================
# 6. CHECK DOCKER DAEMON
# ============================================
echo "[6/11] Verifying Docker daemon..."

# Check if daemon is running
if ! systemctl is-active --quiet docker; then
    echo "Docker daemon is not running, attempting to start..."
    sudo systemctl start docker
    sleep 3
fi

# Try to connect to Docker
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker info >/dev/null 2>&1; then
        echo "✓ Docker daemon is accessible"
        break
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "ERROR: Cannot connect to Docker daemon after $MAX_RETRIES attempts"
        echo ""
        echo "Debugging information:"
        echo "Docker service status:"
        systemctl status docker || true
        echo ""
        echo "Current user groups:"
        groups
        echo ""
        echo "Docker socket permissions:"
        ls -l /var/run/docker.sock || true
        exit 1
    fi
    
    echo "Waiting for Docker daemon... attempt $RETRY_COUNT/$MAX_RETRIES"
    sleep 1
done
echo ""

# ============================================
# 7. VERIFY AWS CLI
# ============================================
echo "[7/11] Checking AWS CLI..."
if ! command -v aws >/dev/null 2>&1; then
    echo "ERROR: AWS CLI is not installed"
    exit 1
fi
echo "✓ AWS CLI found: $(aws --version)"

# Verify AWS credentials
echo "Testing AWS credentials..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "ERROR: AWS credentials not working"
    echo "This EC2 instance needs an IAM role with ECR permissions:"
    echo "  - ecr:GetAuthorizationToken"
    echo "  - ecr:BatchCheckLayerAvailability"
    echo "  - ecr:GetDownloadUrlForLayer"
    echo "  - ecr:BatchGetImage"
    exit 1
fi
echo "✓ AWS credentials working"
aws sts get-caller-identity
echo ""

# ============================================
# 8. LOGIN TO ECR
# ============================================
echo "[8/11] Logging into Amazon ECR..."
if aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY" 2>&1; then
    echo "✓ ECR login successful"
else
    echo "ERROR: ECR login failed"
    echo "Verify IAM role has ecr:GetAuthorizationToken permission"
    exit 1
fi
echo ""

# ============================================
# 9. PULL LATEST IMAGE
# ============================================
echo "[9/11] Pulling latest Docker image..."
IMAGE="${ECR_REGISTRY}/${ECR_REPO}:latest"
echo "Image: $IMAGE"

if docker pull "$IMAGE" 2>&1; then
    echo "✓ Image pulled successfully"
else
    echo "ERROR: Failed to pull image"
    echo ""
    echo "Checking if image exists in ECR..."
    aws ecr describe-images \
        --repository-name "$ECR_REPO" \
        --region "$AWS_REGION" \
        --max-items 5 || echo "Could not list images"
    exit 1
fi
echo ""

# ============================================
# 10. STOP OLD CONTAINERS
# ============================================
echo "[10/11] Stopping old containers..."
docker compose down 2>&1 || echo "No existing containers to stop"

# Clean up dangling containers
echo "Cleaning up old containers..."
docker container prune -f || true
echo ""

# ============================================
# 11. START NEW CONTAINERS
# ============================================
echo "[11/11] Starting new containers..."
if docker compose up -d 2>&1; then
    echo "✓ Containers started successfully"
else
    echo "ERROR: Failed to start containers"
    echo ""
    echo "Docker Compose file contents:"
    cat "$COMPOSE_FILE"
    echo ""
    echo "Docker Compose configuration test:"
    docker compose config || true
    exit 1
fi
echo ""

# ============================================
# VERIFY DEPLOYMENT
# ============================================
echo "Verifying deployment..."
sleep 5

echo "Running containers:"
docker ps
echo ""

if docker ps | grep -q "$CONTAINER_NAME"; then
    echo "✓ Container '$CONTAINER_NAME' is running"
    echo ""
    echo "Container details:"
    docker inspect "$CONTAINER_NAME" --format='Container ID: {{.Id}}
Status: {{.State.Status}}
Started: {{.State.StartedAt}}
Ports: {{range $p, $conf := .NetworkSettings.Ports}}{{$p}} -> {{(index $conf 0).HostPort}} {{end}}'
    echo ""
    echo "Recent logs (last 30 lines):"
    docker logs --tail 30 "$CONTAINER_NAME"
    echo ""
    echo "=========================================="
    echo "   ✓ DEPLOYMENT SUCCESSFUL"
    echo "=========================================="
    exit 0
else
    echo "ERROR: Container '$CONTAINER_NAME' is not running"
    echo ""
    echo "All containers (including stopped):"
    docker ps -a
    echo ""
    echo "Attempting to get logs from failed container:"
    docker logs "$CONTAINER_NAME" 2>&1 || echo "Could not fetch logs"
    echo ""
    echo "Compose file used:"
    cat "$COMPOSE_FILE"
    exit 1
fi