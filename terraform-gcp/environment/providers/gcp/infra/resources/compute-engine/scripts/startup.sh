#!/bin/bash

# ==========================================================================
#  Startup Script for Laravel FrankenPHP Deployment
# --------------------------------------------------------------------------
#  Description: Install Docker and run Laravel FrankenPHP container
# ==========================================================================

set -e

# Variables from Terraform
DOCKER_IMAGE="${docker_image}"
GITHUB_USERNAME="${github_username}"
GITHUB_TOKEN="${github_token}"
FRANKENPHP_PORT="${frankenphp_port}"
APP_KEY="${app_key}"
APP_ENV="${app_env}"
APP_DEBUG="${app_debug}"
DB_HOST="${db_host}"
DB_PORT="${db_port}"
DB_NAME="${db_name}"
DB_USER="${db_user}"
DB_PASSWORD="${db_password}"
ENVIRONMENT="${environment}"
BASE_DOMAIN="${base_domain}"
APP_SUBDOMAIN="${app_subdomain}"
TENANT_ROUTING_ENABLED="${tenant_routing_enabled}"

# Log all output
exec > >(tee /var/log/startup-script.log) 2>&1

echo "=== Starting Laravel FrankenPHP Deployment ==="
echo "Environment: $ENVIRONMENT"
echo "Docker Image: $DOCKER_IMAGE"
echo "FrankenPHP Port: $FRANKENPHP_PORT"
echo "Timestamp: $(date)"

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

# Add ubuntu user to docker group
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
    
    # Create docker config for ubuntu user
    sudo -u ubuntu mkdir -p /home/ubuntu/.docker
    cp /root/.docker/config.json /home/ubuntu/.docker/config.json
    chown ubuntu:ubuntu /home/ubuntu/.docker/config.json
    
    echo "✓ GitHub Container Registry authentication completed"
else
    echo "⚠ GitHub credentials not provided - assuming public image"
fi

# Create application directory
echo "=== Setting up application directory ==="
mkdir -p /opt/laravel
cd /opt/laravel

# Create docker-compose.yml for FrankenPHP with multi-tenant support
echo "=== Creating Docker Compose configuration for FrankenPHP ==="

# Generate SERVER_NAME configuration for multi-tenant
if [ "$TENANT_ROUTING_ENABLED" = "true" ] && [ -n "$BASE_DOMAIN" ]; then
    SERVER_NAME_CONFIG="$APP_SUBDOMAIN.$BASE_DOMAIN:80, *.$APP_SUBDOMAIN.$BASE_DOMAIN:80"
    echo "Multi-tenant routing enabled for: $SERVER_NAME_CONFIG"
else
    SERVER_NAME_CONFIG=":80"
    echo "Single domain configuration: $SERVER_NAME_CONFIG"
fi

cat > docker-compose.yml << EOF
version: '3.8'

services:
  laravel:
    image: $DOCKER_IMAGE
    container_name: laravel-frankenphp
    restart: unless-stopped
    ports:
      - "$FRANKENPHP_PORT:80"
      - "443:443"
    environment:
      - APP_KEY=$APP_KEY
      - APP_ENV=$APP_ENV
      - APP_DEBUG=$APP_DEBUG
      - DB_HOST=$DB_HOST
      - DB_PORT=$DB_PORT
      - DB_DATABASE=$DB_NAME
      - DB_USERNAME=$DB_USER
      - DB_PASSWORD=$DB_PASSWORD
      - LOG_CHANNEL=stderr
      - TZ=UTC
      - SERVER_NAME=$SERVER_NAME_CONFIG
      # Multi-tenant configuration
      - BASE_DOMAIN=$BASE_DOMAIN
      - APP_SUBDOMAIN=$APP_SUBDOMAIN
      - TENANT_ROUTING_ENABLED=$TENANT_ROUTING_ENABLED
      # FrankenPHP specific environment variables
      - FRANKENPHP_CONFIG=worker ./public/frankenphp-worker.php
      - CADDY_GLOBAL_OPTIONS=debug
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

# Create health check endpoint script (if needed)
echo "=== Creating health check configuration ==="
cat > health-check.sh << 'EOF'
#!/bin/bash
# Health check script for FrankenPHP Laravel application

# Check if container is running
if ! docker ps | grep -q laravel-frankenphp; then
    echo "Container not running"
    exit 1
fi

# Check HTTP response
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    echo "Health check passed"
    exit 0
else
    echo "Health check failed - HTTP $HTTP_CODE"
    exit 1
fi
EOF

chmod +x health-check.sh

# Pull Docker image
echo "=== Pulling Docker image ==="
if [ -n "$GITHUB_USERNAME" ] && [ -n "$GITHUB_TOKEN" ]; then
    echo "Pulling private image from GitHub Container Registry..."
    docker-compose pull
else
    echo "Pulling image (assuming public)..."
    docker-compose pull || {
        echo "Failed to pull image. Please check image name and authentication."
        exit 1
    }
fi

# Start FrankenPHP service
echo "=== Starting FrankenPHP Laravel service ==="
docker-compose up -d

# Wait for service to be ready
echo "=== Waiting for FrankenPHP service to be ready ==="
sleep 45

# Check if service is running
echo "=== Checking service status ==="
docker-compose ps

# Test the application
echo "=== Testing FrankenPHP application ==="
for i in {1..15}; do
    if curl -f http://localhost/health 2>/dev/null || curl -f http://localhost/ 2>/dev/null; then
        echo "✓ FrankenPHP Laravel application is healthy!"
        break
    else
        echo "Attempt $i: Application not ready yet, waiting..."
        sleep 10
    fi
    
    if [ $i -eq 15 ]; then
        echo "⚠ Application health check failed after 15 attempts"
        echo "Container logs:"
        docker-compose logs laravel
    fi
done

# Create systemd service for auto-restart
echo "=== Creating systemd service ==="
cat > /etc/systemd/system/laravel-frankenphp.service << EOF
[Unit]
Description=Laravel FrankenPHP Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/laravel
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
ExecReload=/usr/local/bin/docker-compose restart
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl enable laravel-frankenphp.service

# Setup log rotation
echo "=== Setting up log rotation ==="
cat > /etc/logrotate.d/laravel-frankenphp << EOF
/var/log/startup-script.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}

/opt/laravel/storage/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 644 www-data www-data
}
EOF

# Create monitoring script
echo "=== Creating monitoring script ==="
cat > /opt/laravel/monitor.sh << 'EOF'
#!/bin/bash
# Simple monitoring script for FrankenPHP Laravel application

LOG_FILE="/var/log/laravel-monitor.log"

check_container() {
    if docker ps | grep -q laravel-frankenphp; then
        echo "$(date): Container is running" >> $LOG_FILE
        return 0
    else
        echo "$(date): Container is not running - attempting restart" >> $LOG_FILE
        cd /opt/laravel && docker-compose up -d
        return 1
    fi
}

check_health() {
    if curl -f http://localhost/health &>/dev/null || curl -f http://localhost/ &>/dev/null; then
        echo "$(date): Health check passed" >> $LOG_FILE
        return 0
    else
        echo "$(date): Health check failed" >> $LOG_FILE
        return 1
    fi
}

# Run checks
check_container
check_health

# If both checks fail, restart the service
if [ $? -ne 0 ]; then
    echo "$(date): Restarting Laravel FrankenPHP service" >> $LOG_FILE
    systemctl restart laravel-frankenphp
fi
EOF

chmod +x /opt/laravel/monitor.sh

# Add monitoring cron job
echo "=== Setting up monitoring cron job ==="
echo "*/5 * * * * root /opt/laravel/monitor.sh" >> /etc/crontab

# Final status and information
echo "=== Deployment completed ==="
echo "FrankenPHP Laravel application should be available on port $FRANKENPHP_PORT"
echo "Docker containers status:"
docker ps
echo ""
echo "Application logs:"
docker-compose logs --tail=20 laravel
echo ""
echo "Startup script completed at: $(date)"

# Display useful information
echo ""
echo "=== Useful Commands ==="
echo "Check application status: docker-compose ps"
echo "View application logs: docker-compose logs -f laravel"
echo "Restart application: docker-compose restart"
echo "Health check: curl http://localhost/health"
echo "Monitor logs: tail -f /var/log/startup-script.log"