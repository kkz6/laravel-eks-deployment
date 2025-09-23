# Redis-Horizon Connectivity Troubleshooting Guide

## 🎯 Overview

This document provides a systematic approach to troubleshoot Redis connectivity issues between Laravel Horizon (and other Laravel services) running in GKE and Redis VM instances managed by Terraform.

## 🔍 Common Symptoms

- `Connection timed out` errors in Horizon logs
- `NOAUTH Authentication required` errors in HTTP/scheduler logs
- Horizon pods in CrashLoopBackOff state
- Jobs not being processed
- Redis connection failures in Laravel logs

## 📋 Prerequisites

- Access to GCP Console/CLI
- kubectl configured for your GKE cluster
- SSH access to Redis VM
- Knowledge of your Terraform Redis configuration

## 🛠️ Troubleshooting Steps

### Step 1: Verify Redis VM Health

#### 1.1 Check VM Status

```bash
# List Redis VM instances
gcloud compute instances list --filter="name~redis"

# Check VM is running
gcloud compute instances describe <REDIS_VM_NAME> --zone=<ZONE> --format="get(status)"
```

#### 1.2 SSH into Redis VM and Check Service

```bash
# SSH into Redis VM
gcloud compute ssh <REDIS_VM_NAME> --zone=<ZONE>

# Check Redis service status
sudo systemctl status redis-server

# Check Redis processes
ps aux | grep redis

# Check if Redis is listening on correct port
sudo ss -tlnp | grep 6379
```

#### 1.3 Test Redis Connectivity Locally

```bash
# Test without auth (if no password)
redis-cli -h 127.0.0.1 -p 6379 ping

# Test with auth (if password configured)
redis-cli -h 127.0.0.1 -p 6379 -a '<REDIS_PASSWORD>' ping

# Test external connectivity
redis-cli -h <REDIS_VM_INTERNAL_IP> -p 6379 -a '<REDIS_PASSWORD>' ping
```

#### 1.4 Check Redis Configuration

```bash
# Check Redis config file
sudo cat /etc/redis/redis.conf | grep -E "bind|protected-mode|requirepass|port"

# Check Redis runtime config
redis-cli -h 127.0.0.1 -p 6379 -a '<REDIS_PASSWORD>' CONFIG GET bind
redis-cli -h 127.0.0.1 -p 6379 -a '<REDIS_PASSWORD>' CONFIG GET protected-mode
```

**Expected Configuration:**

```
bind 0.0.0.0                    # Allow external connections
port 6379                       # Standard Redis port
protected-mode no               # Disable protected mode (or configure auth)
requirepass <YOUR_PASSWORD>     # If using authentication
```

#### 1.5 Common Redis VM Issues & Fixes

**Issue: Redis service failed/crashed**

```bash
# Check Redis logs
sudo journalctl -u redis-server -n 20

# Common fix: Data directory issues
sudo mkdir -p /var/lib/redis
sudo chown redis:redis /var/lib/redis
sudo chmod 755 /var/lib/redis

# Update Redis config if needed
sudo sed -i 's|dir /mnt/redis-data|dir /var/lib/redis|g' /etc/redis/redis.conf

# Restart Redis
sudo systemctl restart redis-server
```

### Step 2: Verify Network Connectivity

#### 2.1 Get Network Information

```bash
# Get GKE cluster pod CIDR
gcloud container clusters describe <CLUSTER_NAME> --zone=<ZONE> --format="get(clusterIpv4Cidr)"

# Get Redis VM internal IP
gcloud compute instances describe <REDIS_VM_NAME> --zone=<ZONE> --format="get(networkInterfaces[0].networkIP)"

# Get current pod IPs
kubectl get pods -n <NAMESPACE> -o wide | grep -E "(horizon|http|scheduler)"
```

#### 2.2 Check Firewall Rules

```bash
# List firewall rules related to Redis
gcloud compute firewall-rules list --filter="targetTags:redis OR sourceTags:gke"

# Check specific rule details
gcloud compute firewall-rules describe <FIREWALL_RULE_NAME>
```

#### 2.3 Test Network Connectivity

**From GKE Node to Redis VM:**

```bash
# SSH into a GKE node
gcloud compute ssh <GKE_NODE_NAME> --zone=<ZONE>

# Test basic connectivity (if available)
ping <REDIS_VM_IP>
```

**From Pod to Redis VM:**

```bash
# Test from Laravel pod
kubectl exec -n <NAMESPACE> <POD_NAME> -- php -r "
\$redis = new Redis();
try {
    \$result = \$redis->connect('<REDIS_VM_IP>', 6379, 5);
    if (\$result) {
        echo 'Connection successful!\n';
        // Test auth if password is set
        \$auth = \$redis->auth('<REDIS_PASSWORD>');
        echo 'Auth: ' . (\$auth ? 'SUCCESS' : 'FAILED') . '\n';
    } else {
        echo 'Connection failed\n';
    }
} catch (Exception \$e) {
    echo 'Error: ' . \$e->getMessage() . '\n';
}"
```

#### 2.4 Common Network Issues & Fixes

**Issue: Wrong firewall rule CIDR**

```bash
# Create correct firewall rule for GKE pods
gcloud compute firewall-rules create allow-gke-pods-to-redis \
    --allow tcp:6379 \
    --source-ranges <GKE_POD_CIDR> \
    --target-tags <REDIS_VM_TAG> \
    --description "Allow GKE pods to connect to Redis"

# Example with typical values:
gcloud compute firewall-rules create allow-gke-pods-to-redis \
    --allow tcp:6379 \
    --source-ranges 10.1.0.0/16 \
    --target-tags redis-server \
    --description "Allow GKE pods to connect to Redis"
```

**Issue: VM missing target tags**

```bash
# Add tags to Redis VM
gcloud compute instances add-tags <REDIS_VM_NAME> \
    --zone=<ZONE> \
    --tags=redis-server
```

### Step 3: Verify Laravel Configuration

#### 3.1 Check Environment Variables

```bash
# Check current env vars in pods
kubectl exec -n <NAMESPACE> <POD_NAME> -- env | grep -i redis

# Expected variables:
# REDIS_HOST=<REDIS_VM_IP>
# REDIS_PORT=6379
# REDIS_PASSWORD=<PASSWORD>  # If using auth
# QUEUE_CONNECTION=redis
```

#### 3.2 Update Deployments with Redis Password

```bash
# Update all Laravel deployments
kubectl set env deployment/laravel-http -n <NAMESPACE> REDIS_PASSWORD='<REDIS_PASSWORD>'
kubectl set env deployment/laravel-horizon -n <NAMESPACE> REDIS_PASSWORD='<REDIS_PASSWORD>'
kubectl set env deployment/laravel-scheduler -n <NAMESPACE> REDIS_PASSWORD='<REDIS_PASSWORD>'
```

#### 3.3 Check Pod Status and Logs

```bash
# Check pod status
kubectl get pods -n <NAMESPACE>

# Check logs for errors
kubectl logs -n <NAMESPACE> <POD_NAME> --tail=20

# Look for specific errors:
# - "Connection timed out" = Network issue
# - "NOAUTH Authentication required" = Missing password
# - "Connection refused" = Redis not running
```

### Step 4: Terraform Configuration Best Practices

#### 4.1 Redis VM Configuration

```hcl
# Example Terraform Redis VM configuration
resource "google_compute_instance" "redis" {
  name         = "redis-instance"
  machine_type = "e2-small"
  zone         = var.zone

  tags = ["redis-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-2004-lts"
      size  = 20
    }
  }

  network_interface {
    network = "default"
    # Don't assign external IP for security
    # access_config {}
  }

  metadata_startup_script = templatefile("${path.module}/scripts/install-redis.sh", {
    redis_password = var.redis_password
  })
}
```

#### 4.2 Firewall Rules

```hcl
# Get GKE cluster info
data "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone
}

# Firewall rule for GKE pods to Redis
resource "google_compute_firewall" "gke_to_redis" {
  name    = "allow-gke-pods-to-redis"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["6379"]
  }

  source_ranges = [data.google_container_cluster.primary.cluster_ipv4_cidr]
  target_tags   = ["redis-server"]

  description = "Allow GKE pods to connect to Redis"
}
```

#### 4.3 Kubernetes Deployment with Redis Config

```hcl
resource "kubernetes_deployment" "laravel_horizon" {
  metadata {
    name      = "laravel-horizon"
    namespace = var.namespace
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "laravel-horizon"
      }
    }

    template {
      metadata {
        labels = {
          app = "laravel-horizon"
        }
      }

      spec {
        container {
          name  = "horizon"
          image = var.horizon_image

          env {
            name  = "REDIS_HOST"
            value = google_compute_instance.redis.network_interface[0].network_ip
          }

          env {
            name  = "REDIS_PORT"
            value = "6379"
          }

          env {
            name = "REDIS_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.redis_password.metadata[0].name
                key  = "password"
              }
            }
          }

          env {
            name  = "QUEUE_CONNECTION"
            value = "redis"
          }
        }
      }
    }
  }
}

resource "kubernetes_secret" "redis_password" {
  metadata {
    name      = "redis-password"
    namespace = var.namespace
  }

  data = {
    password = var.redis_password
  }

  type = "Opaque"
}
```

## 🚨 Emergency Quick Fixes

### Quick Fix 1: Restart Everything

```bash
# Restart Redis VM
gcloud compute instances reset <REDIS_VM_NAME> --zone=<ZONE>

# Restart all Laravel deployments
kubectl rollout restart deployment/laravel-http -n <NAMESPACE>
kubectl rollout restart deployment/laravel-horizon -n <NAMESPACE>
kubectl rollout restart deployment/laravel-scheduler -n <NAMESPACE>
```

### Quick Fix 2: Temporary Wide-Open Firewall

```bash
# TEMPORARY: Allow all GCP internal traffic to Redis (NOT for production)
gcloud compute firewall-rules create temp-redis-access \
    --allow tcp:6379 \
    --source-ranges 10.0.0.0/8 \
    --target-tags redis-server \
    --description "TEMPORARY - Remove after fixing proper rules"
```

### Quick Fix 3: Remove Redis Authentication Temporarily

```bash
# SSH into Redis VM
gcloud compute ssh <REDIS_VM_NAME> --zone=<ZONE>

# Comment out password requirement (TEMPORARY)
sudo sed -i 's/requirepass/#requirepass/' /etc/redis/redis.conf
sudo systemctl restart redis-server

# Remove REDIS_PASSWORD from deployments
kubectl set env deployment/laravel-http -n <NAMESPACE> REDIS_PASSWORD-
kubectl set env deployment/laravel-horizon -n <NAMESPACE> REDIS_PASSWORD-
kubectl set env deployment/laravel-scheduler -n <NAMESPACE> REDIS_PASSWORD-
```

## 📊 Monitoring and Validation

### Health Checks

```bash
# Redis VM health
gcloud compute ssh <REDIS_VM_NAME> --zone=<ZONE> --command="redis-cli -h 127.0.0.1 ping"

# Laravel pods health
kubectl exec -n <NAMESPACE> <HORIZON_POD> -- php artisan horizon:status
kubectl exec -n <NAMESPACE> <HTTP_POD> -- php artisan cache:clear

# Network connectivity test
kubectl exec -n <NAMESPACE> <POD_NAME> -- php -r "echo (new Redis())->connect('<REDIS_IP>', 6379) ? 'OK' : 'FAIL';"
```

### Log Monitoring

```bash
# Monitor all Laravel pods
kubectl logs -n <NAMESPACE> -l app=laravel-horizon -f --tail=10
kubectl logs -n <NAMESPACE> -l app=laravel-http -f --tail=10

# Monitor Redis VM
gcloud compute ssh <REDIS_VM_NAME> --zone=<ZONE> --command="sudo tail -f /var/log/redis/redis-server.log"
```

## 🔧 Prevention Tips

1. **Use Terraform data sources** to get GKE cluster CIDR dynamically
2. **Store Redis password in Secret Manager** and reference in Terraform
3. **Use health checks** in Kubernetes deployments
4. **Monitor Redis VM disk space** and memory usage
5. **Set up proper logging** and alerting for Redis connectivity
6. **Use Redis Sentinel** or **Redis Cluster** for high availability
7. **Consider using Cloud Memorystore** instead of VM-based Redis

## 📝 Terraform Variables Template

```hcl
variable "redis_password" {
  description = "Redis authentication password"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "default"
}
```

## ✅ Success Indicators

- ✅ Redis VM: `systemctl status redis-server` shows "active (running)"
- ✅ Network: Pods can connect to Redis VM IP:6379
- ✅ Authentication: No "NOAUTH" errors in logs
- ✅ Horizon: Shows "Horizon started successfully" in logs
- ✅ Jobs: Laravel jobs are being processed
- ✅ No CrashLoopBackOff pods

---

**🎯 Remember:** Always test in staging environment first, and keep Redis password secure using Kubernetes secrets or Secret Manager!
