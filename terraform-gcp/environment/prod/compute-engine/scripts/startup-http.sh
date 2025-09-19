#!/bin/bash

# ==========================================================================
#  HTTP Frontend Startup Script
# --------------------------------------------------------------------------
#  Description: Install Docker and run Laravel HTTP frontend container
# ==========================================================================

set -e

# Variables from Terraform
DOCKER_IMAGE="${docker_image}"
GITHUB_USERNAME="${github_username}"
GITHUB_TOKEN="${github_token}"
FRANKENPHP_PORT="${frankenphp_port}"
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
BASE_DOMAIN="${base_domain}"
APP_SUBDOMAIN="${app_subdomain}"
TENANT_ROUTING_ENABLED="${tenant_routing_enabled}"

# Log all output
exec > >(tee /var/log/startup-script.log) 2>&1

echo "=== Starting Laravel HTTP Frontend Deployment ==="
echo "Environment: $ENVIRONMENT"
echo "Container Mode: $CONTAINER_MODE"
echo "Docker Image: $DOCKER_IMAGE"
echo "FrankenPHP Port: $FRANKENPHP_PORT"
echo "Redis Host: $REDIS_HOST:$REDIS_PORT"
echo "Timestamp: $(date)"

# Source common setup functions
source <(curl -s https://raw.githubusercontent.com/devopscorner/laravel-eks-deployment/master/terraform-gcp/scripts/common-setup.sh) 2>/dev/null || {
    # Inline common setup if remote source fails
    
    # Update system
    echo "=== Updating system packages ==="
    apt-get update -y
    apt-get upgrade -y
    
    # Install required packages
    echo "=== Installing required packages ==="
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
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ubuntu
    
    # Install Docker Compose
    echo "=== Installing Docker Compose ==="
    curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Install Google Cloud Ops Agent
    echo "=== Installing Google Cloud Ops Agent ==="
    curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
    bash add-google-cloud-ops-agent-repo.sh --also-install
    
    # GitHub Container Registry Authentication
    echo "=== Setting up GitHub Container Registry authentication ==="
    if [ -n "$GITHUB_USERNAME" ] && [ -n "$GITHUB_TOKEN" ]; then
        echo "Authenticating with GitHub Container Registry..."
        echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
        
        sudo -u ubuntu mkdir -p /home/ubuntu/.docker
        cp /root/.docker/config.json /home/ubuntu/.docker/config.json
        chown ubuntu:ubuntu /home/ubuntu/.docker/config.json
        
        echo "✓ GitHub Container Registry authentication completed"
    else
        echo "⚠ GitHub credentials not provided - assuming public image"
    fi
}

# Create application directory
echo "=== Setting up application directory ==="
mkdir -p /opt/laravel-http
cd /opt/laravel-http

# Generate SERVER_NAME configuration for multi-tenant
if [ "$TENANT_ROUTING_ENABLED" = "true" ] && [ -n "$BASE_DOMAIN" ]; then
    SERVER_NAME_CONFIG="$APP_SUBDOMAIN.$BASE_DOMAIN:$FRANKENPHP_PORT, *.$APP_SUBDOMAIN.$BASE_DOMAIN:$FRANKENPHP_PORT"
    echo "Multi-tenant routing enabled for: $SERVER_NAME_CONFIG"
else
    SERVER_NAME_CONFIG=":$FRANKENPHP_PORT"
    echo "Single domain configuration: $SERVER_NAME_CONFIG"
fi

# Create docker-compose.yml for HTTP frontend
echo "=== Creating Docker Compose configuration for HTTP Frontend ==="
cat > docker-compose.yml << EOF
version: '3.8'

services:
  laravel-http:
    image: $DOCKER_IMAGE
    container_name: laravel-http-frontend
    restart: unless-stopped
    ports:
      - "$FRANKENPHP_PORT:80"
      - "443:443"
    environment:
      - CONTAINER_MODE=http
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
      - SERVER_NAME=$SERVER_NAME_CONFIG
      - BASE_DOMAIN=$BASE_DOMAIN
      - APP_SUBDOMAIN=$APP_SUBDOMAIN
      - TENANT_ROUTING_ENABLED=$TENANT_ROUTING_ENABLED
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
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

# Pull and start services
echo "=== Starting HTTP Frontend Service ==="
docker-compose pull
docker-compose up -d

# Wait for service to be ready
echo "=== Waiting for HTTP service to be ready ==="
sleep 60

# Test the application
echo "=== Testing HTTP Frontend ==="
for i in {1..15}; do
    if curl -f http://localhost/health 2>/dev/null || curl -f http://localhost/ 2>/dev/null; then
        echo "✓ HTTP Frontend is healthy!"
        break
    else
        echo "Attempt $i: HTTP Frontend not ready yet, waiting..."
        sleep 10
    fi
    
    if [ $i -eq 15 ]; then
        echo "⚠ HTTP Frontend health check failed after 15 attempts"
        docker-compose logs laravel-http
    fi
done

# Create systemd service
echo "=== Creating systemd service ==="
cat > /etc/systemd/system/laravel-http.service << EOF
[Unit]
Description=Laravel HTTP Frontend
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/laravel-http
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
ExecReload=/usr/local/bin/docker-compose restart
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl enable laravel-http.service

echo "=== HTTP Frontend deployment completed ==="
echo "Service should be available on port $FRANKENPHP_PORT"
echo "Docker status:"
docker ps
echo "Startup script completed at: $(date)"
