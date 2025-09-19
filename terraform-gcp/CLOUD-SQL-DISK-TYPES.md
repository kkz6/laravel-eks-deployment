# Cloud SQL Disk Types Reference

## Valid Cloud SQL Disk Types

Google Cloud SQL uses different disk types than Compute Engine:

### 💾 **Cloud SQL Disk Types**

| Type     | Performance               | Cost/GB/month | Use Case                     |
| -------- | ------------------------- | ------------- | ---------------------------- |
| `PD_HDD` | 3 IOPS per GB (min 180)   | $0.027        | Staging, development         |
| `PD_SSD` | 30 IOPS per GB (min 3000) | $0.170        | Production, high performance |

### ⚠️ **Invalid Types for Cloud SQL**

- ~~`PD_STANDARD`~~ ← This was causing your error
- ~~`pd-standard`~~
- ~~`standard`~~

## Comparison: Cloud SQL vs Compute Engine

### 🗄️ **Cloud SQL Disk Types**

```hcl
# ✅ VALID for Cloud SQL
disk_type = "PD_HDD"    # Cheapest
disk_type = "PD_SSD"    # Fastest
```

### 💻 **Compute Engine Disk Types**

```hcl
# ✅ VALID for Compute Engine (different naming)
disk_type = "pd-standard"  # Standard persistent disk
disk_type = "pd-ssd"       # SSD persistent disk
disk_type = "pd-balanced"  # Balanced persistent disk
```

## Performance Characteristics

### 🐌 **PD_HDD (Staging)**

- **IOPS**: 3 per GB (minimum 180 IOPS for 10GB)
- **Throughput**: Up to 120 MB/s read, 120 MB/s write
- **Latency**: 5-10ms
- **Cost**: $0.027/GB/month
- **Best for**: Development, testing, low-traffic staging

### ⚡ **PD_SSD (Production)**

- **IOPS**: 30 per GB (minimum 3000 IOPS for 10GB)
- **Throughput**: Up to 1,200 MB/s read, 1,200 MB/s write
- **Latency**: 1-2ms
- **Cost**: $0.170/GB/month
- **Best for**: Production, high-traffic applications

## Cost Comparison (10GB Database)

| Disk Type   | Monthly Cost | Annual Cost | Performance        |
| ----------- | ------------ | ----------- | ------------------ |
| **PD_HDD**  | $0.27        | $3.24       | 180 IOPS           |
| **PD_SSD**  | $1.70        | $20.40      | 3,000 IOPS         |
| **Savings** | $1.43        | $17.16      | 94% cost reduction |

## Environment-Based Configuration

### 🧪 **Staging (Automatic)**

```hcl
# Your current configuration automatically uses:
disk_type = "PD_HDD"     # Cheapest option
disk_size = 10           # Small size
```

### 🏭 **Production (When you switch workspace)**

```hcl
# Will automatically use:
disk_type = var.database_disk_type  # PD_SSD from variables
disk_size = var.database_disk_size  # Larger size from variables
```

## Performance Impact

### 📊 **Real-World Performance**

**PD_HDD (Staging):**

- **Small Laravel app**: Perfectly adequate
- **Multi-tenant staging**: Handles 5-10 concurrent users
- **Database operations**: Standard CRUD operations work fine
- **Bottleneck**: Usually application code, not disk I/O

**PD_SSD (Production):**

- **Large Laravel app**: Handles high traffic
- **Multi-tenant production**: 100+ concurrent users
- **Database operations**: Fast complex queries
- **Bottleneck**: Usually network or CPU

## Migration Path

### 🔄 **Staging to Production**

When ready for production:

1. **Switch workspace**:

   ```bash
   terraform workspace select prod
   ```

2. **Update variables** (if needed):

   ```hcl
   database_disk_type = "PD_SSD"
   database_disk_size = 50
   ```

3. **Deploy**:
   ```bash
   terraform apply
   ```

### 📈 **Disk Resize (Live)**

You can resize disks without downtime:

```bash
# Increase disk size (can't decrease)
gcloud sql instances patch laravel-db-staging \
  --storage-size=20GB
```

## Monitoring Disk Performance

### 📊 **Key Metrics to Watch**

1. **Disk IOPS Utilization**

   ```bash
   gcloud monitoring metrics list --filter="metric.type:cloudsql_database"
   ```

2. **Disk Queue Depth**

   - High queue depth = need faster disks
   - Low utilization = can use cheaper disks

3. **Query Performance**
   ```sql
   -- Check slow queries
   SHOW PROCESSLIST;
   SELECT * FROM INFORMATION_SCHEMA.PROCESSLIST WHERE TIME > 5;
   ```

## Troubleshooting

### 🐛 **Common Issues**

1. **Disk Type Error**:

   ```
   Error: Invalid value "PD_STANDARD"
   ```

   **Fix**: Use `PD_HDD` or `PD_SSD`

2. **Performance Issues**:

   - Check if you need PD_SSD instead of PD_HDD
   - Monitor IOPS utilization
   - Consider increasing disk size (more IOPS)

3. **Cost Concerns**:
   - PD_HDD is 84% cheaper than PD_SSD
   - Start with PD_HDD, upgrade if needed
   - Monitor actual usage vs allocated resources

## Summary

### ✅ **Fixed Configuration**

Your database now uses:

- **Staging**: `PD_HDD` (cheapest, adequate performance)
- **Production**: `PD_SSD` (high performance when needed)
- **Cost**: ~$7.94/month for staging (even cheaper now!)
- **Performance**: 180 IOPS for staging, 3000+ IOPS for production

The error is now resolved, and your staging environment will be very cost-effective while still providing good performance for testing your multi-tenant Laravel application! 💰🚀
