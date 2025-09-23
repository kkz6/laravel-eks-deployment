# Redis Connectivity Fixes - Implementation Summary

## 🎯 Overview

This document summarizes the comprehensive fixes applied to resolve Redis connectivity issues between Laravel Horizon (and other Laravel services) running in GKE and Redis VM instances, following the troubleshooting guide in `Redis-Horizon-Troubleshooting-Guide.md`.

## 🚨 Issues Identified & Fixed

### **1. Firewall Rule Problems** ✅ FIXED

#### **Issue:**

- **Staging**: Wrong firewall rule using source/target tags instead of CIDR ranges
- **Production**: Missing firewall rule entirely for Redis VM access
- Both environments not using proper GKE pod CIDR ranges

#### **Root Cause:**

- Firewall rules were using `source_tags` and `target_tags` which only work for VM-to-VM communication
- GKE pods get IPs from pod CIDR ranges (`10.1.0.0/16` for staging, VPC secondary ranges for prod)
- Redis VMs had inconsistent network tags

#### **Fix Applied:**

```hcl
# BEFORE (staging):
resource "google_compute_firewall" "allow_redis_from_gke" {
  source_tags = ["laravel-gke-node"]  # ❌ Wrong - doesn't cover pod IPs
  target_tags = ["laravel-redis"]     # ❌ Wrong - VM has different tags
}

# AFTER (staging):
resource "google_compute_firewall" "allow_gke_pods_to_redis" {
  source_ranges = ["10.1.0.0/16"]    # ✅ Correct - GKE pod CIDR
  target_tags   = ["redis-server"]    # ✅ Correct - matches VM tags
}

# AFTER (production):
resource "google_compute_firewall" "allow_gke_pods_to_redis" {
  network       = data.terraform_remote_state.vpc.outputs.vpc_name
  source_ranges = [data.terraform_remote_state.vpc.outputs.gke_pod_cidr]
  target_tags   = ["redis-server"]
}
```

### **2. Redis Authentication Issues** ✅ FIXED

#### **Issue:**

- Redis setup script generated random passwords but Kubernetes secrets had empty passwords
- No mechanism to retrieve and use the generated Redis password
- Mismatch between Redis config (requires auth) and Laravel config (no auth)

#### **Root Cause:**

```bash
# Redis setup script:
requirepass $(openssl rand -base64 32)  # Generated random password

# Kubernetes secret:
REDIS_PASSWORD = ""  # Empty password!
```

#### **Fix Applied:**

1. **Added Redis password variable:**

```hcl
variable "redis_password" {
  type        = string
  description = "Redis authentication password"
  sensitive   = true
  default     = ""
}
```

2. **Updated setup script to use provided password:**

```bash
# Variables from Terraform
REDIS_PASSWORD="${redis_password}"

# Security configuration
requirepass $REDIS_PASSWORD
```

3. **Added fallback random password generation:**

```hcl
resource "random_password" "redis_password" {
  count   = var.redis_password == "" ? 1 : 0
  length  = 32
  special = true
}
```

4. **Fixed Kubernetes secrets:**

```hcl
data = {
  REDIS_PASSWORD = var.redis_password != "" ? var.redis_password : random_password.redis_password[0].result
}
```

### **3. Network Tag Mismatches** ✅ FIXED

#### **Issue:**

- **Staging**: Redis VM had tags `["laravel-redis", "laravel-internal"]`
- **Production**: Redis VM had tags `["redis-server", "ssh-allowed"]`
- Firewall rules didn't match the actual VM tags

#### **Fix Applied:**

- Standardized Redis VM tags to `["redis-server", "ssh-allowed"]` for both environments
- Updated firewall rules to use `target_tags = ["redis-server"]`

## 📊 Configuration Changes Summary

### **Files Modified:**

#### **Staging Environment:**

- `terraform-gcp/environment/staging/gke/redis-vm.tf`
- `terraform-gcp/environment/staging/gke/scripts/setup-redis.sh`
- `terraform-gcp/environment/staging/gke/variables.tf`
- `terraform-gcp/environment/staging/gke/kubernetes-resources.tf`
- `terraform-gcp/environment/staging/gke/outputs.tf`

#### **Production Environment:**

- `terraform-gcp/environment/prod/gke/redis-vm.tf`
- `terraform-gcp/environment/prod/gke/scripts/setup-redis.sh`
- `terraform-gcp/environment/prod/gke/variables.tf`
- `terraform-gcp/environment/prod/gke/kubernetes-resources.tf`
- `terraform-gcp/environment/prod/gke/outputs.tf`

### **Key Configuration Changes:**

#### **1. Firewall Rules:**

```hcl
# Staging (Default VPC)
resource "google_compute_firewall" "allow_gke_pods_to_redis" {
  name          = "laravel-allow-gke-pods-to-redis-${var.environment[local.env]}"
  network       = "default"
  source_ranges = ["10.1.0.0/16"]  # GKE pod CIDR
  target_tags   = ["redis-server"]
  allow {
    protocol = "tcp"
    ports    = ["6379"]
  }
}

# Production (Custom VPC)
resource "google_compute_firewall" "allow_gke_pods_to_redis" {
  name          = "laravel-allow-gke-pods-to-redis-${var.environment[local.env]}"
  network       = data.terraform_remote_state.vpc.outputs.vpc_name
  source_ranges = [data.terraform_remote_state.vpc.outputs.gke_pod_cidr]
  target_tags   = ["redis-server"]
  allow {
    protocol = "tcp"
    ports    = ["6379"]
  }
}
```

#### **2. Redis VM Configuration:**

```hcl
resource "google_compute_instance" "redis_vm" {
  # Consistent network tags
  tags = ["redis-server", "ssh-allowed"]

  # Startup script with password
  metadata = {
    startup-script = templatefile("${path.module}/scripts/setup-redis.sh", {
      redis_version  = var.redis_version
      environment    = var.environment[local.env]
      redis_password = var.redis_password != "" ? var.redis_password : random_password.redis_password[0].result
    })
  }
}
```

#### **3. Kubernetes Secrets:**

```hcl
resource "kubernetes_secret" "laravel_secrets" {
  data = {
    REDIS_HOST     = local.redis_host
    REDIS_PORT     = "6379"
    REDIS_PASSWORD = var.redis_password != "" ? var.redis_password : random_password.redis_password[0].result
  }
}
```

## 🚀 Deployment Instructions

### **1. Update terraform.tfvars**

Add Redis password to your `terraform.tfvars`:

```hcl
# Optional: Provide specific Redis password (recommended for production)
redis_password = "your-secure-redis-password-here"

# If not provided, a random 32-character password will be generated
```

### **2. Deploy Changes**

```bash
# For Staging
cd terraform-gcp/environment/staging/gke
terraform plan
terraform apply

# For Production
cd terraform-gcp/environment/prod/gke
terraform plan
terraform apply
```

### **3. Verify Redis Connection**

```bash
# Get Redis connection details
terraform output redis_internal_ip
terraform output -raw redis_password

# Test from a Laravel pod
kubectl exec -n laravel-app <pod-name> -- php -r "
\$redis = new Redis();
\$result = \$redis->connect('REDIS_IP', 6379, 5);
\$auth = \$redis->auth('REDIS_PASSWORD');
echo \$redis->ping() ? 'SUCCESS' : 'FAILED';
"
```

## 🔍 Troubleshooting Commands

### **Network Connectivity Test:**

```bash
# Test firewall rules
gcloud compute firewall-rules list --filter="name~redis"

# Test from GKE pod
kubectl run redis-test --rm -i --tty --image=redis:alpine -- redis-cli -h REDIS_IP -p 6379 -a 'PASSWORD' ping
```

### **Redis VM Health Check:**

```bash
# SSH into Redis VM
gcloud compute ssh laravel-redis-stg --zone=us-central1-a

# Check Redis status
sudo systemctl status redis-server
redis-cli -a 'PASSWORD' ping
```

### **Laravel Application Logs:**

```bash
# Check Horizon logs
kubectl logs -n laravel-app -l app=laravel-horizon --tail=20

# Check HTTP service logs
kubectl logs -n laravel-app -l app=laravel-http --tail=20
```

## ✅ Success Indicators

After applying these fixes, you should see:

- ✅ **Network**: `kubectl exec` Redis connection tests succeed
- ✅ **Authentication**: No "NOAUTH Authentication required" errors
- ✅ **Firewall**: Rules allow GKE pod CIDR → Redis VM:6379
- ✅ **Horizon**: Shows "Horizon started successfully" in logs
- ✅ **Jobs**: Laravel queue jobs are being processed
- ✅ **No CrashLoopBackOff**: All pods running normally

## 🛡️ Security Improvements

1. **Password Management**: Redis now uses proper authentication
2. **Network Segmentation**: Firewall rules only allow necessary traffic
3. **Sensitive Data**: Redis passwords marked as sensitive in Terraform
4. **Least Privilege**: VM service accounts have minimal required permissions

## 📝 Next Steps

1. **Monitor Redis Performance**: Set up monitoring for Redis VM
2. **Backup Strategy**: Implement Redis data backup procedures
3. **High Availability**: Consider Redis Sentinel or Cloud Memorystore for production
4. **Scaling**: Monitor Redis memory usage and scale VM size if needed

---

**🎯 Key Takeaway**: The root cause was network connectivity (wrong firewall rules) combined with authentication mismatch (empty passwords). These fixes address both issues comprehensively while following the troubleshooting guide recommendations.
