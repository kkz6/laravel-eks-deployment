#!/bin/bash

# ==========================================================================
#  Redis VM Setup Script
# --------------------------------------------------------------------------
#  Description: Install and configure Redis on Ubuntu VM
# ==========================================================================

set -e

# Variables from Terraform
REDIS_VERSION="${redis_version}"
ENVIRONMENT="${environment}"
REDIS_PASSWORD="${redis_password}"

# Log all output
exec > >(tee /var/log/redis-setup.log) 2>&1

echo "=== Starting Redis Setup ==="
echo "Redis Version: $REDIS_VERSION"
echo "Environment: $ENVIRONMENT"
echo "Timestamp: $(date)"

# Update system
echo "=== Updating system packages ==="
apt-get update -y
apt-get upgrade -y

# Install required packages
echo "=== Installing required packages ==="
apt-get install -y \
    curl \
    wget \
    gnupg \
    lsb-release \
    software-properties-common \
    htop \
    vim

# Install Redis
echo "=== Installing Redis ==="
curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list

apt-get update -y
apt-get install -y redis-server

# Setup persistent data directory
echo "=== Setting up persistent storage ==="
mkdir -p /mnt/redis-data
chown redis:redis /mnt/redis-data
chmod 750 /mnt/redis-data

# Mount additional disk if available
if lsblk | grep -q sdb; then
    echo "=== Mounting additional disk for Redis data ==="
    mkfs.ext4 -F /dev/sdb
    mount /dev/sdb /mnt/redis-data
    echo "/dev/sdb /mnt/redis-data ext4 defaults 0 2" >> /etc/fstab
    chown redis:redis /mnt/redis-data
fi

# Configure Redis
echo "=== Configuring Redis ==="
cat > /etc/redis/redis.conf << EOF
# Redis configuration for Laravel
bind 0.0.0.0
port 6379
protected-mode no
timeout 300

# Memory and persistence
maxmemory 512mb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000

# Data directory
dir /mnt/redis-data

# Logging
loglevel notice
logfile /var/log/redis/redis-server.log

# Security (basic)
requirepass $REDIS_PASSWORD

# Performance
tcp-keepalive 300
tcp-backlog 511
databases 16

# Laravel-specific optimizations
notify-keyspace-events Ex
EOF

# Store the Redis password for reference
echo "Redis password: $REDIS_PASSWORD" > /opt/redis-password.txt
chmod 600 /opt/redis-password.txt

# Install Google Cloud Ops Agent for monitoring
echo "=== Installing Google Cloud Ops Agent ==="
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install

# Configure Redis systemd service
echo "=== Configuring Redis service ==="
systemctl enable redis-server
systemctl restart redis-server

# Wait for Redis to start
sleep 10

# Test Redis connection
echo "=== Testing Redis ==="
if redis-cli -a "$REDIS_PASSWORD" ping | grep -q PONG; then
    echo "✓ Redis is responding correctly"
else
    echo "✗ Redis connection failed"
    systemctl status redis-server
fi

# Setup Redis monitoring
echo "=== Setting up Redis monitoring ==="
cat > /opt/redis-monitor.sh << 'EOF'
#!/bin/bash
# Simple Redis monitoring
if ! systemctl is-active --quiet redis-server; then
    echo "$(date): Redis service down - restarting" >> /var/log/redis-monitor.log
    systemctl restart redis-server
fi
EOF

chmod +x /opt/redis-monitor.sh

# Add monitoring cron job
echo "*/5 * * * * root /opt/redis-monitor.sh" >> /etc/crontab

# Setup log rotation
echo "=== Setting up log rotation ==="
cat > /etc/logrotate.d/redis-custom << EOF
/var/log/redis/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 redis redis
    postrotate
        systemctl reload redis-server
    endscript
}
EOF

# Create info file for Kubernetes to discover Redis
echo "=== Creating Redis connection info ==="
cat > /opt/redis-info.json << EOF
{
  "host": "$(hostname -I | awk '{print $1}')",
  "port": 6379,
  "password": "$REDIS_PASSWORD",
  "version": "$REDIS_VERSION",
  "environment": "$ENVIRONMENT"
}
EOF

echo "=== Redis setup completed ==="
echo "Redis is running on: $(hostname -I | awk '{print $1}'):6379"
echo "Redis password stored in: /opt/redis-password.txt"
echo "Connection info: /opt/redis-info.json"
echo "Redis status:"
systemctl status redis-server --no-pager
echo "Setup completed at: $(date)"
