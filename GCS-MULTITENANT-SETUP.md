# Google Cloud Storage Multi-Tenant Setup for Laravel

This document provides instructions for setting up Google Cloud Storage (GCS) access for your multi-tenant Laravel application deployed on Google Kubernetes Engine (GKE).

## Overview

Your Laravel application is configured to:
- Create tenant-specific GCS buckets dynamically
- Use Workload Identity for secure authentication (recommended)
- Access GCS without storing service account keys in your containers

## Architecture

```
Laravel Pod (with Workload Identity)
    ↓
Kubernetes Service Account (laravel)
    ↓ (Workload Identity binding)
Google Service Account (laravel-gcs-{env})
    ↓ (IAM permissions)
Google Cloud Storage
    ├── Shared bucket: {project-id}-laravel-shared-{env}
    └── Tenant buckets: {project-id}-tenant-{tenant-id}-{env}
```

## Prerequisites

1. GKE cluster with Workload Identity enabled
2. Terraform for infrastructure provisioning
3. Helm for application deployment

## Setup Instructions

### 1. Deploy Infrastructure with Terraform

Navigate to your environment directory and apply the GCS configuration:

```bash
# For staging environment
cd terraform-gcp/environment/staging/gke
terraform plan
terraform apply

# For production environment  
cd terraform-gcp/environment/prod/gke
terraform plan
terraform apply
```

This will create:
- Service account: `laravel-gcs-{env}@{project-id}.iam.gserviceaccount.com`
- Shared bucket: `{project-id}-laravel-shared-{env}`
- IAM permissions for bucket creation and management
- Workload Identity binding

### 2. Deploy Laravel Application

The Laravel application is deployed using Terraform, which manages all Kubernetes resources directly. The GCS configuration has been automatically added to the Terraform files.

```bash
# Deploy using the deploy.sh script
cd terraform-gcp
./deploy.sh -p YOUR_PROJECT_ID -e staging -a apply -y

# For production
./deploy.sh -p YOUR_PROJECT_ID -e prod -a apply -y
```

The deployment script will:
- Create the GCS service account and bucket
- Set up Workload Identity binding
- Deploy Laravel with all GCS environment variables
- Configure the Kubernetes service account with proper annotations

## Laravel Configuration

Your Laravel application should be configured with these filesystem settings:

```php
// config/filesystems.php
'disks' => [
    'gcs' => [
        'driver' => 'gcs',
        'key_file_path' => env('GOOGLE_CLOUD_KEY_FILE', null), // Not needed with Workload Identity
        'key_file' => [], // Not needed with Workload Identity
        'project_id' => env('GOOGLE_CLOUD_PROJECT_ID', 'your-project-id'),
        'bucket' => env('GOOGLE_CLOUD_STORAGE_BUCKET', 'your-bucket'),
        'bucket_prefix' => env('GCS_BUCKET_PREFIX', 'tenant'),
        'bucket_location' => env('GCS_BUCKET_LOCATION', 'US'),
        'storage_class' => env('GCS_STORAGE_CLASS', 'STANDARD'),
        'path_prefix' => env('GOOGLE_CLOUD_STORAGE_PATH_PREFIX', ''),
        'storage_api_uri' => env('GOOGLE_CLOUD_STORAGE_API_URI', null),
        'api_endpoint' => env('GOOGLE_CLOUD_STORAGE_API_ENDPOINT', null),
        'visibility' => 'public',
        'visibility_handler' => null,
        'metadata' => ['cacheControl' => 'public,max-age=86400'],
    ],
],
```

## Multi-Tenant Bucket Management

### Bucket Naming Convention

Tenant-specific buckets follow this pattern:
```
{project-id}-tenant-{tenant-id}-{environment}
```

Examples:
- `myproject-tenant-acme-corp-staging`
- `myproject-tenant-tech-startup-prod`

### Laravel Implementation Example

```php
<?php

namespace App\Services;

use Illuminate\Support\Facades\Storage;
use Google\Cloud\Storage\StorageClient;

class TenantStorageService
{
    protected $storage;
    protected $projectId;
    protected $environment;

    public function __construct()
    {
        $this->storage = new StorageClient([
            'projectId' => config('filesystems.disks.gcs.project_id'),
        ]);
        $this->projectId = config('filesystems.disks.gcs.project_id');
        $this->environment = app()->environment();
    }

    public function getTenantBucketName($tenantId)
    {
        return "{$this->projectId}-tenant-{$tenantId}-{$this->environment}";
    }

    public function createTenantBucket($tenantId, $location = 'US', $storageClass = 'STANDARD')
    {
        $bucketName = $this->getTenantBucketName($tenantId);
        
        if (!$this->bucketExists($bucketName)) {
            $bucket = $this->storage->createBucket($bucketName, [
                'location' => $location,
                'storageClass' => $storageClass,
                'versioning' => ['enabled' => true],
                'cors' => [[
                    'origin' => ['*'],
                    'method' => ['GET', 'HEAD', 'PUT', 'POST', 'DELETE'],
                    'responseHeader' => ['*'],
                    'maxAgeSeconds' => 3600,
                ]],
            ]);
            
            return $bucket;
        }
        
        return $this->storage->bucket($bucketName);
    }

    public function getTenantDisk($tenantId)
    {
        $bucketName = $this->getTenantBucketName($tenantId);
        
        // Ensure bucket exists
        $this->createTenantBucket($tenantId);
        
        // Configure dynamic disk
        config([
            "filesystems.disks.tenant_{$tenantId}" => array_merge(
                config('filesystems.disks.gcs'),
                ['bucket' => $bucketName]
            )
        ]);
        
        return Storage::disk("tenant_{$tenantId}");
    }

    protected function bucketExists($bucketName)
    {
        try {
            $this->storage->bucket($bucketName)->info();
            return true;
        } catch (\Google\Cloud\Core\Exception\NotFoundException $e) {
            return false;
        }
    }
}
```

### Usage in Controllers

```php
<?php

namespace App\Http\Controllers;

use App\Services\TenantStorageService;
use Illuminate\Http\Request;

class FileController extends Controller
{
    protected $tenantStorage;

    public function __construct(TenantStorageService $tenantStorage)
    {
        $this->tenantStorage = $tenantStorage;
    }

    public function upload(Request $request)
    {
        $tenantId = $request->user()->tenant_id; // Get from your tenant context
        $disk = $this->tenantStorage->getTenantDisk($tenantId);
        
        $path = $disk->putFile('uploads', $request->file('file'));
        
        return response()->json([
            'path' => $path,
            'url' => $disk->url($path)
        ]);
    }
}
```

## Security Considerations

### IAM Permissions

The service account has these permissions:
- `roles/storage.admin` - Full access to create/manage buckets and objects
- `roles/storage.buckets.create` - Explicit bucket creation permission
- `roles/serviceusage.serviceUsageConsumer` - Use GCS APIs

### Workload Identity Benefits

1. **No service account keys** in containers or configuration
2. **Automatic credential rotation** managed by Google
3. **Fine-grained permissions** per Kubernetes service account
4. **Audit trail** through Cloud IAM logs

## Troubleshooting

### Common Issues

1. **Permission Denied Errors**
   ```bash
   # Check Workload Identity binding
   kubectl describe serviceaccount laravel -n devopscorner-dev
   
   # Verify GCP service account permissions
   gcloud projects get-iam-policy YOUR_PROJECT_ID
   ```

2. **Bucket Creation Failures**
   ```bash
   # Check if service account has bucket creation permissions
   gcloud projects get-iam-policy YOUR_PROJECT_ID \
     --flatten="bindings[].members" \
     --filter="bindings.members:serviceAccount:laravel-gcs-stg@YOUR_PROJECT_ID.iam.gserviceaccount.com"
   ```

3. **Workload Identity Not Working**
   ```bash
   # Test from inside pod
   kubectl exec -it <pod-name> -n devopscorner-dev -- \
     curl -H "Metadata-Flavor: Google" \
     http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token
   ```

### Verification Commands

```bash
# List buckets accessible to the service account
gsutil ls -p YOUR_PROJECT_ID

# Test bucket creation (from inside pod)
gsutil mb gs://test-bucket-name

# Check Workload Identity status
gcloud container clusters describe CLUSTER_NAME \
  --zone=ZONE \
  --format="value(workloadIdentityConfig.workloadPool)"
```

## Environment Variables Reference

| Variable | Description | Example |
|----------|-------------|---------|
| `GOOGLE_CLOUD_PROJECT_ID` | Your GCP Project ID | `myproject-123456` |
| `GOOGLE_CLOUD_STORAGE_BUCKET` | Shared bucket for common assets | `myproject-laravel-shared-stg` |
| `GCS_BUCKET_PREFIX` | Prefix for tenant buckets | `tenant` |
| `GCS_BUCKET_LOCATION` | Bucket location | `US`, `EU`, `ASIA` |
| `GCS_STORAGE_CLASS` | Storage class | `STANDARD`, `NEARLINE`, `COLDLINE` |
| `GOOGLE_CLOUD_STORAGE_PATH_PREFIX` | Path prefix within buckets | `uploads/` |
| `GOOGLE_CLOUD_STORAGE_API_URI` | Custom API endpoint (optional) | `https://storage.googleapis.com` |

## Cost Optimization

1. **Use appropriate storage classes** for different data types
2. **Implement lifecycle policies** to automatically delete old files
3. **Monitor bucket usage** with Cloud Monitoring
4. **Use regional buckets** for better performance and lower costs

## Monitoring and Logging

Set up monitoring for:
- Bucket creation/deletion events
- Storage usage per tenant
- API request patterns
- Error rates

Use Cloud Logging to track:
- Authentication events
- Permission changes
- Bucket operations
