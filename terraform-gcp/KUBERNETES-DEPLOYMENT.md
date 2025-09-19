# Laravel Kubernetes Deployment Guide

## 🎯 **Pure Kubernetes Architecture**

Your Laravel application now runs on **Google Kubernetes Engine (GKE)** with:

### **🐳 Container Modes (Same Image, Different Behavior):**

```yaml
# HTTP Frontend Pods (Auto-scaling: 2-10 pods)
CONTAINER_MODE: "http"
- Your Dockerfile starts FrankenPHP web server
- Handles web requests and multi-tenant routing
- Behind Kubernetes Ingress with SSL

# Scheduler Pod (Single Pod, Never Scales)
CONTAINER_MODE: "scheduler"
- Your Dockerfile starts Laravel scheduler
- Runs cron jobs and scheduled tasks
- Always exactly 1 pod

# Horizon Worker Pods (Auto-scaling: 1-5 pods)
CONTAINER_MODE: "horizon"
- Your Dockerfile starts Laravel Horizon
- Processes background jobs from Redis
- Scales based on CPU usage
```

### **🏗️ Supporting Infrastructure:**

- **Cloud SQL**: Managed MySQL database (~$8/month)
- **Redis VM**: Cost-effective Redis instance (~$15/month)
- **GKE Cluster**: Container orchestration (~$25/month)

## 🚀 **Deployment Commands**

### **1. Setup GCP Project:**

```bash
cd terraform-gcp
./setup-gcp.sh -p zyoshu-test
```

### **2. Deploy Everything:**

```bash
./deploy.sh -p zyoshu-test -e staging -a apply
```

### **3. Verify Deployment:**

```bash
# Check pods
kubectl get pods -n laravel-app

# Check services
kubectl get services -n laravel-app

# Check ingress (for external IP)
kubectl get ingress -n laravel-app

# Check auto-scaling
kubectl get hpa -n laravel-app
```

## 📋 **What Gets Deployed:**

### **Terraform Infrastructure:**

1. **Terraform State**: GCS bucket for state management
2. **Cloud SQL**: Managed MySQL database
3. **GKE Cluster**: Kubernetes cluster with auto-scaling nodes
4. **Redis VM**: Dedicated VM for Redis with persistent storage

### **Kubernetes Resources:**

1. **Namespace**: `laravel-app`
2. **Secrets**: Database and Redis credentials
3. **Deployments**: HTTP, Scheduler, Horizon
4. **Services**: ClusterIP service for HTTP pods
5. **Ingress**: Multi-tenant routing with SSL
6. **HPA**: Auto-scaling for HTTP and Horizon

## 🔧 **Container Configuration:**

### **All Containers Use Same Environment:**

```yaml
environment:
  # Laravel basics
  - APP_KEY: "your-app-key"
  - APP_ENV: "production"
  - APP_DEBUG: "false"

  # Database (Cloud SQL)
  - DB_HOST: "cloud-sql-ip"
  - DB_DATABASE: "laravel_app"
  - DB_USERNAME: "laravel_user"
  - DB_PASSWORD: "auto-generated"

  # Redis (VM)
  - REDIS_HOST: "redis-vm-internal-ip"
  - REDIS_PORT: "6379"
  - REDIS_PASSWORD: "auto-generated"

  # Multi-tenant
  - BASE_DOMAIN: "zyoshu.com"
  - APP_SUBDOMAIN: "app"
  - TENANT_ROUTING_ENABLED: "true"

  # Container mode (different for each deployment)
  - CONTAINER_MODE: "http|scheduler|horizon"
```

## 🎛️ **Auto-Scaling Behavior:**

### **HTTP Pods (Web Traffic):**

- **Min**: 2 pods
- **Max**: 10 pods
- **Triggers**: CPU > 70%, Memory > 80%
- **Scale Up**: Fast (60s window)
- **Scale Down**: Conservative (300s window)

### **Horizon Pods (Queue Processing):**

- **Min**: 1 pod
- **Max**: 5 pods
- **Triggers**: CPU > 80%, Memory > 85%
- **Scale Up**: Fast for queue processing
- **Scale Down**: Slow to avoid job interruption

### **Scheduler Pod (Cron Jobs):**

- **Fixed**: Always 1 pod
- **Strategy**: Recreate (prevents duplicate schedulers)
- **No Scaling**: Critical for avoiding duplicate cron jobs

## 🌐 **Multi-Tenant Ingress:**

```yaml
# Handles all tenant traffic
app.zyoshu.com       → HTTP Pods
*.app.zyoshu.com     → HTTP Pods

# Examples:
tenant1.app.zyoshu.com → Same HTTP Pods
tenant2.app.zyoshu.com → Same HTTP Pods
acme.app.zyoshu.com    → Same HTTP Pods
```

## 📊 **Monitoring Commands:**

```bash
# Pod status
kubectl get pods -n laravel-app -o wide

# Auto-scaling status
kubectl get hpa -n laravel-app

# Resource usage
kubectl top pods -n laravel-app

# Logs
kubectl logs -f deployment/laravel-http -n laravel-app
kubectl logs -f deployment/laravel-horizon -n laravel-app
kubectl logs -f deployment/laravel-scheduler -n laravel-app

# Redis status
gcloud compute ssh laravel-redis-staging --command="redis-cli info stats"

# Database status
gcloud sql instances describe laravel-db-staging
```

## 🔄 **Operational Commands:**

### **Manual Scaling:**

```bash
# Scale HTTP frontend
kubectl scale deployment laravel-http --replicas=5 -n laravel-app

# Scale Horizon workers
kubectl scale deployment laravel-horizon --replicas=3 -n laravel-app

# Scheduler always stays at 1 (automatic)
```

### **Rolling Updates:**

```bash
# Update to new container image
kubectl set image deployment/laravel-http laravel-http=ghcr.io/zyoshu-inc/zyoshu-modular:new-tag -n laravel-app

# Update all deployments
kubectl set image deployment/laravel-http laravel-http=ghcr.io/zyoshu-inc/zyoshu-modular:v1.2.0 -n laravel-app
kubectl set image deployment/laravel-scheduler laravel-scheduler=ghcr.io/zyoshu-inc/zyoshu-modular:v1.2.0 -n laravel-app
kubectl set image deployment/laravel-horizon laravel-horizon=ghcr.io/zyoshu-inc/zyoshu-modular:v1.2.0 -n laravel-app

# Check rollout status
kubectl rollout status deployment/laravel-http -n laravel-app
```

### **Debugging:**

```bash
# Exec into pods
kubectl exec -it deployment/laravel-http -n laravel-app -- bash
kubectl exec -it deployment/laravel-horizon -n laravel-app -- bash

# Check events
kubectl get events -n laravel-app --sort-by=.metadata.creationTimestamp

# Describe resources
kubectl describe pod laravel-http-xxx-xxx -n laravel-app
```

## 💰 **Cost Breakdown (Staging):**

| Component         | Configuration      | Monthly Cost      |
| ----------------- | ------------------ | ----------------- |
| **GKE Cluster**   | 2x e2-medium nodes | ~$25              |
| **Cloud SQL**     | db-f1-micro, 10GB  | ~$8               |
| **Redis VM**      | e2-small, 20GB     | ~$15              |
| **Load Balancer** | Kubernetes Ingress | ~$18              |
| **Static IP**     | Reserved IP        | ~$1.50            |
| **Total**         |                    | **~$67.50/month** |

## 🎯 **Benefits Over VM Approach:**

### **✅ Kubernetes Advantages:**

- **Rolling Updates**: Zero-downtime deployments
- **Self-Healing**: Automatic pod restarts
- **Resource Efficiency**: Better resource utilization
- **Service Discovery**: Built-in pod-to-pod communication
- **Declarative**: Infrastructure as code with YAML
- **Ecosystem**: Rich tooling and monitoring

### **✅ Your Container Intelligence:**

- **Single Image**: Same container, different modes
- **Environment Driven**: `CONTAINER_MODE` controls behavior
- **Laravel Native**: Scheduler and Horizon work as designed
- **Clean Separation**: Clear responsibility boundaries

## 🚀 **Ready to Deploy!**

Your Kubernetes architecture is now complete:

```bash
# Deploy everything
./deploy.sh -p zyoshu-test -e staging -a apply

# Configure Cloudflare DNS with the ingress IP
# Test your multi-tenant application
```

This gives you enterprise-grade Laravel infrastructure with proper Kubernetes orchestration! 🎉
