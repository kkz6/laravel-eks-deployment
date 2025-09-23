# Laravel Multi-Tenant GCS Deployment - Quick Reference

## Overview

Your Laravel application is now configured for multi-tenant Google Cloud Storage access using:
- **Terraform** for infrastructure and Kubernetes resource management
- **Workload Identity** for secure GCS authentication
- **Dynamic bucket creation** for tenant isolation

## Deployment Commands

### First-Time Setup

```bash
# 1. Navigate to terraform directory
cd terraform-gcp

# 2. Deploy staging environment
./deploy.sh -p YOUR_PROJECT_ID -e staging -a apply -y

# 3. Deploy production environment (when ready)
./deploy.sh -p YOUR_PROJECT_ID -e prod -a apply -y
```

### What Gets Created

#### Infrastructure
- **GKE Cluster**: `laravel-cluster-{env}`
- **GCS Service Account**: `laravel-gcs-{env}@{project-id}.iam.gserviceaccount.com`
- **Shared Bucket**: `{project-id}-laravel-shared-{env}`
- **Cloud SQL Database**: MySQL instance for Laravel
- **Redis VM**: For caching and queues

#### Kubernetes Resources
- **Namespace**: `laravel-app`
- **Service Account**: `laravel` (with Workload Identity)
- **Deployments**: 
  - `laravel-http` (web server)
  - `laravel-scheduler` (cron jobs)
  - `laravel-horizon` (queue worker)
- **ConfigMap**: `laravel-config` (with GCS environment variables)
- **Secrets**: `laravel-secrets` (database credentials)

## GCS Configuration

### Environment Variables (Auto-configured)

```bash
GOOGLE_CLOUD_PROJECT_ID=your-project-id
GOOGLE_CLOUD_STORAGE_BUCKET=your-project-laravel-shared-env
GCS_BUCKET_PREFIX=tenant
GCS_BUCKET_LOCATION=US
GCS_STORAGE_CLASS=STANDARD
```

### Bucket Naming Convention

- **Shared bucket**: `{project-id}-laravel-shared-{env}`
- **Tenant buckets**: `{project-id}-tenant-{tenant-id}-{env}`

Examples:
- `myproject-laravel-shared-staging`
- `myproject-tenant-acme-corp-staging`
- `myproject-tenant-tech-startup-prod`

## Laravel Implementation

### Service Class Example

```php
// app/Services/TenantStorageService.php
use Google\Cloud\Storage\StorageClient;

class TenantStorageService
{
    public function getTenantDisk($tenantId)
    {
        $bucketName = $this->getTenantBucketName($tenantId);
        $this->createTenantBucket($tenantId);
        
        config([
            "filesystems.disks.tenant_{$tenantId}" => array_merge(
                config('filesystems.disks.gcs'),
                ['bucket' => $bucketName]
            )
        ]);
        
        return Storage::disk("tenant_{$tenantId}");
    }
}
```

### Controller Usage

```php
public function upload(Request $request)
{
    $tenantId = $request->user()->tenant_id;
    $disk = $this->tenantStorage->getTenantDisk($tenantId);
    
    $path = $disk->putFile('uploads', $request->file('file'));
    
    return response()->json([
        'path' => $path,
        'url' => $disk->url($path)
    ]);
}
```

## Troubleshooting

### Check Deployment Status

```bash
# Configure kubectl
cd terraform-gcp/environment/staging/gke
eval $(terraform output -raw kubectl_config_command)

# Check pods
kubectl get pods -n laravel-app

# Check service account
kubectl describe serviceaccount laravel -n laravel-app

# Check logs
kubectl logs -f deployment/laravel-http -n laravel-app
```

### Verify GCS Access

```bash
# Test from inside pod
kubectl exec -it deployment/laravel-http -n laravel-app -- \
  curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token
```

### Common Issues

1. **Workload Identity not working**: Check service account annotations
2. **Permission denied**: Verify IAM bindings in GCP Console
3. **Bucket creation fails**: Check `storage.admin` role assignment

## Monitoring

### Key Metrics to Watch
- Pod CPU/Memory usage
- GCS API request rates
- Storage usage per tenant
- Authentication failures

### Logs to Monitor
- Laravel application logs
- Kubernetes events
- GCP IAM audit logs

## Security Notes

✅ **No service account keys** stored in containers  
✅ **Workload Identity** provides automatic credential rotation  
✅ **Tenant isolation** through separate buckets  
✅ **Least privilege** IAM permissions  

## Cost Optimization

- Use lifecycle policies to delete old files
- Choose appropriate storage classes (STANDARD, NEARLINE, COLDLINE)
- Monitor storage usage per tenant
- Set up budget alerts in GCP Console

## Next Steps After Deployment

1. Configure DNS records for your domain
2. Set up SSL certificates (handled by cert-manager)
3. Test multi-tenant bucket creation
4. Set up monitoring and alerting
5. Configure backup strategies
