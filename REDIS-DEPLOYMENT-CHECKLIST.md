# Redis Connectivity Fixes - Deployment Checklist

## 📋 Pre-Deployment Checklist

### **1. Environment Preparation**

- [ ] Backup current Terraform state files
- [ ] Document current Redis VM IP addresses
- [ ] Note current Laravel pod status
- [ ] Save current firewall rules for rollback if needed

### **2. Configuration Updates**

- [ ] Review `terraform.tfvars` files
- [ ] Add `redis_password` variable (optional but recommended)
- [ ] Verify GCP project ID and region settings
- [ ] Confirm VPC configuration for production environment

## 🚀 Deployment Steps

### **Staging Environment**

```bash
cd terraform-gcp/environment/staging/gke

# 1. Review changes
terraform plan

# 2. Apply changes
terraform apply

# 3. Verify outputs
terraform output redis_internal_ip
terraform output -raw redis_password
```

### **Production Environment**

```bash
cd terraform-gcp/environment/prod/gke

# 1. Review changes
terraform plan

# 2. Apply changes
terraform apply

# 3. Verify outputs
terraform output redis_internal_ip
terraform output -raw redis_password
```

## ✅ Post-Deployment Verification

### **1. Infrastructure Verification**

```bash
# Check Redis VM status
gcloud compute instances list --filter="name~redis"

# Check firewall rules
gcloud compute firewall-rules list --filter="name~redis"

# Verify VM tags
gcloud compute instances describe <redis-vm-name> --zone=<zone> --format="get(tags.items)"
```

### **2. Network Connectivity Test**

```bash
# Test from GKE pod
kubectl run redis-test --rm -i --tty --image=redis:alpine -- redis-cli -h <REDIS_IP> -p 6379 -a '<PASSWORD>' ping

# Expected output: PONG
```

### **3. Laravel Application Health**

```bash
# Check pod status
kubectl get pods -n laravel-app

# Check Horizon logs
kubectl logs -n laravel-app -l app=laravel-horizon --tail=10

# Check for Redis connection errors
kubectl logs -n laravel-app -l app=laravel-http --tail=20 | grep -i redis
```

### **4. Redis VM Health Check**

```bash
# SSH into Redis VM
gcloud compute ssh <redis-vm-name> --zone=<zone>

# Check Redis service
sudo systemctl status redis-server

# Test local Redis connection
redis-cli -a '<PASSWORD>' ping

# Check Redis configuration
redis-cli -a '<PASSWORD>' CONFIG GET requirepass
redis-cli -a '<PASSWORD>' CONFIG GET bind
```

## 🔧 Troubleshooting

### **Common Issues & Solutions**

#### **Issue: "Connection timed out"**

```bash
# Check firewall rules
gcloud compute firewall-rules describe laravel-allow-gke-pods-to-redis-<env>

# Verify source ranges match GKE pod CIDR
kubectl get nodes -o wide
```

#### **Issue: "NOAUTH Authentication required"**

```bash
# Check Kubernetes secret
kubectl get secret laravel-secrets -n laravel-app -o yaml | base64 -d

# Verify Redis password in VM
gcloud compute ssh <redis-vm-name> --zone=<zone> --command="cat /opt/redis-password.txt"
```

#### **Issue: Redis service not running**

```bash
# SSH into Redis VM and check
sudo systemctl status redis-server
sudo journalctl -u redis-server -n 20

# Check Redis configuration
sudo cat /etc/redis/redis.conf | grep -E "bind|requirepass|port"
```

## 🚨 Rollback Plan

If issues occur, follow these rollback steps:

### **1. Immediate Rollback**

```bash
# Revert Terraform changes
git checkout HEAD~1 terraform-gcp/environment/<env>/gke/

# Apply previous configuration
terraform apply
```

### **2. Emergency Redis Access**

```bash
# Temporary: Remove Redis authentication
gcloud compute ssh <redis-vm-name> --zone=<zone>
sudo sed -i 's/requirepass/#requirepass/' /etc/redis/redis.conf
sudo systemctl restart redis-server

# Remove REDIS_PASSWORD from deployments
kubectl set env deployment/laravel-horizon -n laravel-app REDIS_PASSWORD-
kubectl set env deployment/laravel-http -n laravel-app REDIS_PASSWORD-
```

## 📊 Success Metrics

After deployment, verify these metrics:

- [ ] **Network**: All Redis connectivity tests pass
- [ ] **Authentication**: No authentication errors in logs
- [ ] **Performance**: Redis response time < 5ms
- [ ] **Availability**: All Laravel pods running (0 CrashLoopBackOff)
- [ ] **Functionality**: Queue jobs processing successfully
- [ ] **Monitoring**: No Redis-related alerts

## 📞 Support Contacts

If issues persist:

1. **Infrastructure Team**: Check GCP console for VM and network status
2. **DevOps Team**: Review Terraform state and Kubernetes resources
3. **Application Team**: Verify Laravel Redis configuration
4. **On-Call Engineer**: For production incidents

---

**⚠️ Important**: Always test in staging environment first before applying to production!
