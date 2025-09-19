#!/bin/bash

# ==========================================================================
#  Horizon Worker Startup Script
# --------------------------------------------------------------------------
#  Description: Install Docker and run Laravel Horizon worker container
# ==========================================================================

set -e

# Variables from Terraform
DOCKER_IMAGE="${docker_image}"
GITHUB_USERNAME="${github_username}"
GITHUB_TOKEN="${github_token}"
CONTAINER_MODE="${container_mode}"
APP_KEY="${app_key}"
APP_ENV="${app_env}"
APP_DEBUG="${app_debug}"
DB_HOST="${db_host}"
DB_PORT="${db_port}"
DB_NAME="${db_name}"
DB_USER="${db_user}"
DB_PASSWORD="${db_password}"
REDIS_HOST="${redis_host}"
REDIS_PORT="${redis_port}"
REDIS_AUTH="${redis_auth}"
ENVIRONMENT="${environment}"

# Log all output
exec > >(tee /var/log/startup-script.log) 2>&1

echo "=== Starting Laravel Horizon Worker Deployment ==="
echo "Environment: $ENVIRONMENT"
echo "Container Mode: $CONTAINER_MODE"
echo "Docker Image: $DOCKER_IMAGE"
echo "Redis Host: $REDIS_HOST:$REDIS_PORT"
echo "Timestamp: $(date)"

# Basic system setup (same as HTTP)
apt-get update -y
apt-get upgrade -y

apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    unzip \
    wget \
    htop \
    vim \
    git \
    jq

# Install Docker
echo "=== Installing Docker ==="
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Google Cloud Ops Agent
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install

# GitHub authentication
if [ -n "$GITHUB_USERNAME" ] && [ -n "$GITHUB_TOKEN" ]; then
    echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
    sudo -u ubuntu mkdir -p /home/ubuntu/.docker
    cp /root/.docker/config.json /home/ubuntu/.docker/config.json
    chown ubuntu:ubuntu /home/ubuntu/.docker/config.json
fi

# Create application directory
echo "=== Setting up Horizon worker directory ==="
mkdir -p /opt/laravel-horizon
cd /opt/laravel-horizon

# Create docker-compose.yml for Horizon Workers
echo "=== Creating Docker Compose configuration for Horizon Workers ==="
cat > docker-compose.yml << EOF
version: '3.8'

services:
  laravel-horizon:
    image: $DOCKER_IMAGE
    container_name: laravel-horizon-worker
    restart: unless-stopped
    environment:
      - CONTAINER_MODE=horizon
      - APP_KEY=$APP_KEY
      - APP_ENV=$APP_ENV
      - APP_DEBUG=$APP_DEBUG
      - DB_HOST=$DB_HOST
      - DB_PORT=$DB_PORT
      - DB_DATABASE=$DB_NAME
      - DB_USERNAME=$DB_USER
      - DB_PASSWORD=$DB_PASSWORD
      - REDIS_HOST=$REDIS_HOST
      - REDIS_PORT=$REDIS_PORT
      - REDIS_PASSWORD=$REDIS_AUTH
      - LOG_CHANNEL=stderr
      - TZ=UTC
      - QUEUE_CONNECTION=redis
    healthcheck:
      test: ["CMD", "ps", "aux"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 120s
    volumes:
      - laravel_storage:/app/storage
      - laravel_cache:/app/bootstrap/cache
      - laravel_logs:/app/storage/logs
    networks:
      - laravel_network

volumes:
  laravel_storage:
  laravel_cache:
  laravel_logs:

networks:
  laravel_network:
    driver: bridge
EOF

# Pull and start Horizon workers
echo "=== Starting Horizon Worker Service ==="
docker-compose pull
docker-compose up -d

# Wait for Horizon to initialize
echo "=== Waiting for Horizon to initialize ==="
sleep 90

# Verify Horizon container is running
echo "=== Verifying Horizon Container ==="
if docker ps | grep -q laravel-horizon; then
    echo "✓ Horizon container is running"
    echo "✓ Internal Horizon queue processing will be handled by the container"
else
    echo "✗ Horizon container failed to start"
    docker-compose logs laravel-horizon
fi

# Create systemd service
echo "=== Creating systemd service ==="
cat > /etc/systemd/system/laravel-horizon.service << EOF
[Unit]
Description=Laravel Horizon Workers
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/laravel-horizon
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
ExecReload=/usr/local/bin/docker-compose restart
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl enable laravel-horizon.service

# Container handles everything internally - no external monitoring needed

echo "=== Horizon Worker deployment completed ==="
echo "Worker container status:"
docker ps
echo "Startup script completed at: $(date)"
