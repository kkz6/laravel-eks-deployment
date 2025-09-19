# Hybrid Laravel Architecture: Cloud SQL + Redis VM + GKE

## 🏗️ **Architecture Overview**

```
┌─────────────────────────────────────────────────────────────────┐
│                        Cloudflare DNS                          │
│                    app.zyoshu.com                              │
│                    *.app.zyoshu.com                            │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────┴───────────────────────────────────────────┐
│                   Google Cloud Load Balancer                   │
│                     (Static IP)                                │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────┴───────────────────────────────────────────┐
│                  GKE Kubernetes Cluster                        │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   HTTP Pods     │  │ Scheduler Pod   │  │  Horizon Pods   │ │
│  │ (Auto-scaling)  │  │  (Single Pod)   │  │ (Auto-scaling)  │ │
│  │ CONTAINER_MODE= │  │ CONTAINER_MODE= │  │ CONTAINER_MODE= │ │
│  │     http        │  │   scheduler     │  │    horizon      │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────┬───────────────────┬───────────────────────┘
                      │                   │
              ┌───────┴────────┐  ┌───────┴────────┐
              │   Cloud SQL    │  │   Redis VM     │
              │   (Managed)    │  │ (Cost-effective│
              │    MySQL       │  │   Single VM)   │
              └────────────────┘  └────────────────┘
```

## 🎯 **Why This Hybrid Approach?**

### **✅ Best of All Worlds:**

| Component         | Technology | Why This Choice                              |
| ----------------- | ---------- | -------------------------------------------- |
| **Database**      | Cloud SQL  | Managed, backups, HA options                 |
| **Cache/Queues**  | Redis VM   | Cost-effective, full control                 |
| **Containers**    | GKE        | Orchestration, auto-scaling, rolling updates |
| **Load Balancer** | Google LB  | Integrated with GKE, SSL termination         |

### **💰 Cost Comparison:**

| Component      | Hybrid Cost          | Alternative Cost        | Savings       |
| -------------- | -------------------- | ----------------------- | ------------- |
| **Database**   | Cloud SQL: ~$8/month | Same                    | $0            |
| **Redis**      | VM: ~$15/month       | Memorystore: ~$45/month | **$30/month** |
| **Containers** | GKE: ~$25/month      | Compute VMs: ~$30/month | **$5/month**  |
| **Total**      | **~$48/month**       | ~$83/month              | **$35/month** |

## 🐳 **Container Architecture**

### **Your Smart Container Modes:**

```yaml
# Same Docker image, different behavior based on CONTAINER_MODE

HTTP Frontend Pods:
  environment:
    CONTAINER_MODE: "http"
  # Your Dockerfile starts FrankenPHP web server
  # Handles: Web requests, multi-tenant routing
  # Scaling: 2-10 pods based on traffic

Scheduler Pod:
  environment:
    CONTAINER_MODE: "scheduler"
  # Your Dockerfile starts Laravel scheduler
  # Handles: Cron jobs, scheduled tasks
  # Scaling: Always exactly 1 pod

Horizon Worker Pods:
  environment:
    CONTAINER_MODE: "horizon"
  # Your Dockerfile starts Laravel Horizon
  # Handles: Background job processing
  # Scaling: 1-5 pods based on queue size
```

## 🚀 **Deployment Workflow**

### **1. Infrastructure Setup:**

```bash
cd terraform-gcp

# Setup GCP project
./setup-gcp.sh -p zyoshu-test

# Deploy hybrid infrastructure
./deploy-hybrid.sh -p zyoshu-test -e staging -a apply
```

### **2. What Gets Created:**

#### **Cloud SQL Database:**

- Instance: `db-f1-micro` (staging)
- Storage: 10GB PD_HDD
- Cost: ~$8/month

#### **Redis VM:**

- Instance: `e2-small`
- Storage: 20GB persistent disk
- Redis: Latest version with persistence
- Cost: ~$15/month

#### **GKE Cluster:**

- Nodes: 2x `e2-medium` (auto-scaling 1-10)
- Kubernetes: Latest stable version
- Workload Identity enabled
- Cost: ~$25/month

### **3. Kubernetes Resources:**

```bash
# Check deployment status
kubectl get pods -n laravel-app

# Expected output:
NAME                               READY   STATUS    RESTARTS
laravel-http-xxx-xxx              1/1     Running   0
laravel-http-xxx-yyy              1/1     Running   0
laravel-scheduler-xxx-xxx         1/1     Running   0
laravel-horizon-xxx-xxx           1/1     Running   0
```

## 🔧 **Configuration Files Created:**

### **Terraform Infrastructure:**

- `gke/gke-cluster.tf` - GKE cluster configuration
- `gke/redis-vm.tf` - Redis VM setup
- `gke/variables.tf` - Configuration variables

### **Kubernetes Manifests:**

- `k8s-manifests/namespace.yaml` - Laravel namespace
- `k8s-manifests/secrets.yaml` - Database/Redis credentials
- `k8s-manifests/http-deployment.yaml` - HTTP frontend pods
- `k8s-manifests/scheduler-deployment.yaml` - Scheduler pod
- `k8s-manifests/horizon-deployment.yaml` - Horizon worker pods
- `k8s-manifests/ingress.yaml` - Multi-tenant ingress

### **Deployment Scripts:**

- `deploy-hybrid.sh` - Complete hybrid deployment
- `setup-gcp.sh` - GCP project setup

## 🎛️ **Auto-Scaling Configuration**

### **HTTP Frontend (Web Traffic):**

```yaml
minReplicas: 2
maxReplicas: 10
metrics:
  - CPU: 70%
  - Memory: 80%
```

### **Horizon Workers (Queue Processing):**

```yaml
minReplicas: 1
maxReplicas: 5
metrics:
  - CPU: 80%
  - Memory: 85%
```

### **Scheduler (No Scaling):**

```yaml
replicas: 1 # Always exactly 1
strategy: Recreate # Prevent multiple schedulers
```

## 🔒 **Security Features**

### **Network Security:**

- GKE private nodes (optional)
- Redis VM internal IP only
- Firewall rules for Redis access
- Workload Identity for secure pod-to-GCP communication

### **Application Security:**

- Kubernetes secrets for sensitive data
- GitHub Container Registry authentication
- SSL termination at load balancer
- Multi-tenant isolation

## 📊 **Monitoring & Observability**

### **Built-in Monitoring:**

```bash
# GKE monitoring
kubectl top pods -n laravel-app
kubectl logs -f deployment/laravel-http -n laravel-app

# Redis monitoring
gcloud compute ssh laravel-redis-staging --command="redis-cli info"

# Database monitoring
gcloud sql instances describe laravel-db-staging
```

### **Cloud Monitoring Integration:**

- Container metrics in GKE
- Redis VM metrics
- Cloud SQL performance metrics
- Custom application metrics

## 🔄 **Operational Commands**

### **Scaling:**

```bash
# Scale HTTP frontend
kubectl scale deployment laravel-http --replicas=5 -n laravel-app

# Scale Horizon workers
kubectl scale deployment laravel-horizon --replicas=3 -n laravel-app

# Scheduler always stays at 1 (no manual scaling)
```

### **Updates:**

```bash
# Update container image
kubectl set image deployment/laravel-http laravel-http=ghcr.io/zyoshu-inc/zyoshu-modular:new-tag -n laravel-app

# Rolling restart
kubectl rollout restart deployment/laravel-http -n laravel-app
```

### **Debugging:**

```bash
# Check pod logs
kubectl logs -f deployment/laravel-http -n laravel-app
kubectl logs -f deployment/laravel-horizon -n laravel-app

# Exec into pods
kubectl exec -it deployment/laravel-http -n laravel-app -- bash

# Check Redis
gcloud compute ssh laravel-redis-staging --command="redis-cli monitor"
```

## 🎯 **Benefits of This Architecture**

### **✅ Kubernetes Advantages:**

- **Container Orchestration**: Automatic pod management
- **Rolling Updates**: Zero-downtime deployments
- **Resource Efficiency**: Multiple containers per node
- **Self-Healing**: Automatic pod restarts
- **Service Discovery**: Built-in networking

### **✅ Hybrid Advantages:**

- **Cost Optimization**: VM Redis vs expensive Memorystore
- **Managed Database**: Cloud SQL reliability without complexity
- **Flexibility**: Can switch components independently
- **Scalability**: Auto-scaling where it matters

### **✅ Your Container Intelligence:**

- **Single Image**: Same container, different modes
- **Clean Separation**: HTTP, scheduler, horizon roles
- **Laravel Native**: Horizon, scheduler work as designed
- **Environment Driven**: `CONTAINER_MODE` controls behavior

## 🚀 **Ready to Deploy!**

Your hybrid architecture is now complete with:

- ✅ **GKE cluster** for container orchestration
- ✅ **Cloud SQL** for managed database
- ✅ **Redis VM** for cost-effective caching/queues
- ✅ **Multi-tenant ingress** for domain routing
- ✅ **Auto-scaling** for HTTP and Horizon
- ✅ **Single scheduler** that never scales

Deploy with:

```bash
./deploy-hybrid.sh -p zyoshu-test -e staging -a apply
```

This gives you enterprise-grade Laravel infrastructure with the best cost/performance balance! 🎉
