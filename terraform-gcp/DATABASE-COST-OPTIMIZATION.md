# Cloud SQL Cost Optimization Guide

## Environment-Based Configuration

Your infrastructure now automatically adjusts database configuration based on the environment to optimize costs.

## Cost Comparison

### 💰 **Staging Environment (Current Configuration)**

| Resource          | Configuration | Monthly Cost (approx.) |
| ----------------- | ------------- | ---------------------- |
| **Database Tier** | `db-f1-micro` | ~$7.67                 |
| **Storage**       | 10GB PD_HDD   | ~$0.27                 |
| **Backups**       | Disabled      | $0.00                  |
| **Availability**  | ZONAL         | $0.00                  |
| **Read Replicas** | None          | $0.00                  |
| **Total**         |               | **~$7.94/month**       |

### 🏢 **Production Environment (When deployed)**

| Resource          | Configuration     | Monthly Cost (approx.) |
| ----------------- | ----------------- | ---------------------- |
| **Database Tier** | `db-g1-small`     | ~$25.55                |
| **Storage**       | 50GB PD_SSD       | ~$8.50                 |
| **Backups**       | 30 days retention | ~$2.00                 |
| **Availability**  | REGIONAL          | +50% of compute        |
| **Read Replicas** | Optional          | +100% of compute       |
| **Total**         |                   | **~$50-70/month**      |

### 💡 **Cost Savings: Staging vs Production**

- **Staging**: ~$8/month (84% cost reduction)
- **Production**: ~$60/month (full features)
- **Annual Savings**: ~$624/year for staging environment

## Automatic Environment Configuration

### 🧪 **Staging Environment (`terraform workspace select staging`)**

```hcl
# Automatically configured:
tier              = "db-f1-micro"        # Smallest instance
availability_type = "ZONAL"              # Single zone
disk_size         = 10                   # 10GB storage
disk_type         = "PD_HDD"             # HDD disk (cheapest)
backups_enabled   = false                # No backups
binary_log        = false                # No binary logs
retention_days    = 1                    # Minimal retention
```

### 🏭 **Production Environment (`terraform workspace select prod`)**

```hcl
# Automatically configured:
tier              = var.database_tier    # Your specified tier
availability_type = var.availability_type # REGIONAL for HA
disk_size         = var.database_disk_size # Your specified size
disk_type         = var.database_disk_type # PD_SSD for performance
backups_enabled   = true                 # Full backups
binary_log        = true                 # Point-in-time recovery
retention_days    = 7                    # 7-day retention
```

## Database Specifications

### 📊 **db-f1-micro (Staging)**

| Specification   | Value                            |
| --------------- | -------------------------------- |
| **vCPUs**       | Shared (burstable)               |
| **RAM**         | 0.6 GB                           |
| **Network**     | Up to 250 Mbps                   |
| **Connections** | Up to 250                        |
| **Use Case**    | Development, testing, small apps |
| **Performance** | Basic, suitable for staging      |

### 🚀 **db-g1-small (Production)**

| Specification   | Value                      |
| --------------- | -------------------------- |
| **vCPUs**       | 1 vCPU                     |
| **RAM**         | 1.7 GB                     |
| **Network**     | Up to 1 Gbps               |
| **Connections** | Up to 1000                 |
| **Use Case**    | Small to medium production |
| **Performance** | Consistent, dedicated CPU  |

## Storage Options

### 💾 **PD_HDD (Staging)**

- **Performance**: Up to 180 IOPS (3 IOPS per GB)
- **Cost**: $0.027/GB/month (cheapest option)
- **Use Case**: Development, non-critical workloads
- **Throughput**: Up to 120 MB/s

### ⚡ **PD_SSD (Production)**

- **Performance**: Up to 3,000 IOPS per GB
- **Cost**: $0.170/GB/month
- **Use Case**: Production, high-performance needs
- **Throughput**: Up to 1,200 MB/s

## Backup Strategy by Environment

### 🧪 **Staging Backups**

```hcl
backup_configuration {
  enabled                = false  # Disabled to save costs
  binary_log_enabled     = false  # No point-in-time recovery
  retained_backups       = 3      # If enabled, minimal retention
}
```

**Rationale**: Staging data is not critical and can be recreated

### 🏭 **Production Backups**

```hcl
backup_configuration {
  enabled                = true   # Full backup protection
  binary_log_enabled     = true   # Point-in-time recovery
  retained_backups       = 30     # 30-day retention
  start_time            = "03:00" # Off-peak hours
}
```

**Rationale**: Production data requires full protection

## Cost Optimization Tips

### 💰 **Additional Savings for Staging**

1. **Scheduled Shutdown** (Manual):

   ```bash
   # Stop database during off-hours (weekends/nights)
   gcloud sql instances patch laravel-db-staging --activation-policy=NEVER
   # Restart when needed
   gcloud sql instances patch laravel-db-staging --activation-policy=ALWAYS
   ```

2. **Development-Only Features**:

   - Disable SSL for local development
   - Use smaller connection pools
   - Minimal database flags

3. **Shared Staging Database**:
   - Multiple staging environments can share one database
   - Use different database names: `laravel_staging_1`, `laravel_staging_2`

### 🏭 **Production Optimizations**

1. **Right-Sizing**:

   - Monitor CPU/Memory usage
   - Scale up/down based on actual needs
   - Use Cloud Monitoring alerts

2. **Read Replicas**:

   - Only add if read traffic is high
   - Consider regional placement for global users

3. **Connection Pooling**:
   - Use PgBouncer/ProxySQL for connection management
   - Reduce connection overhead

## Migration Path

### 🔄 **Staging to Production**

When ready for production:

1. **Update terraform.tfvars**:

   ```hcl
   database_tier      = "db-g1-small"  # or larger
   database_disk_size = 50             # or more
   database_disk_type = "PD_SSD"
   availability_type  = "REGIONAL"     # for high availability
   ```

2. **Switch workspace**:

   ```bash
   terraform workspace select prod
   terraform plan
   terraform apply
   ```

3. **Data Migration**:

   ```bash
   # Export from staging
   gcloud sql export sql laravel-db-staging gs://your-bucket/staging-export.sql

   # Import to production
   gcloud sql import sql laravel-db-prod gs://your-bucket/staging-export.sql
   ```

## Monitoring Costs

### 📊 **Cost Tracking**

1. **GCP Billing Alerts**:

   ```bash
   # Set up billing alerts for your project
   gcloud alpha billing budgets create --billing-account=YOUR_BILLING_ACCOUNT \
     --display-name="Laravel Staging Budget" \
     --budget-amount=50
   ```

2. **Resource Labels**:

   ```hcl
   labels = {
     environment = "staging"
     project     = "laravel-app"
     cost-center = "development"
   }
   ```

3. **Monthly Reviews**:
   - Check GCP Billing dashboard
   - Identify cost trends
   - Optimize based on usage patterns

## Performance Expectations

### 🧪 **Staging Performance**

- **Concurrent Users**: 5-10
- **Response Time**: 100-500ms (acceptable for testing)
- **Throughput**: 50-100 requests/minute
- **Data Size**: Up to 1GB comfortably

### 🏭 **Production Performance**

- **Concurrent Users**: 50-200
- **Response Time**: <100ms
- **Throughput**: 1000+ requests/minute
- **Data Size**: 10GB+ with good performance

## Summary

Your current configuration provides:

✅ **Cost-Effective Staging**: ~$8/month vs ~$60/month for full production  
✅ **Automatic Environment Scaling**: Configuration adapts to workspace  
✅ **Easy Production Migration**: Simple terraform workspace switch  
✅ **Proper Resource Allocation**: Right-sized for each environment  
✅ **Backup Strategy**: Disabled for staging, full protection for production

This setup gives you a professional staging environment at a fraction of production costs while maintaining the ability to scale up seamlessly when ready! 💰🚀
