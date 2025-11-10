# File Upload Fix for GKE Deployment

## Problem
Files uploaded through the GKE ingress were losing their filenames, resulting in files being saved as just `.pdf` (extension only) in the media table and GCS bucket.

## Root Cause
The issue was caused by **missing ingress annotations** for handling multipart form data and large file uploads in the GKE ingress configuration. The Google Cloud Load Balancer was truncating or not properly forwarding the multipart form data, which caused the filename to be lost during upload.

## Solution

### 1. Backend Application Fix
**File:** `/app/Actions/File/UploadFilesAction.php`

Improved the filename extraction logic to be more robust:
- Use `pathinfo()` instead of manual string manipulation for better reliability
- Added proper validation and sanitization
- Added fallback mechanism with timestamps
- Added debug logging to troubleshoot upload issues

**Changes made:**
- Replaced `substr()` and `strrpos()` with `pathinfo()` for filename extraction
- Added regex sanitization to remove problematic characters
- Added comprehensive logging for debugging
- Improved empty filename detection

### 2. GKE Ingress Configuration Fix (CRITICAL)
**File:** `/environment/staging/k8s-manifests/ingress.yaml`

Added critical annotations for file upload handling:

```yaml
# File upload configuration - CRITICAL for file uploads
nginx.ingress.kubernetes.io/proxy-body-size: "50m"
nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
nginx.ingress.kubernetes.io/proxy-send-timeout: "300"
nginx.ingress.kubernetes.io/proxy-connect-timeout: "300"
nginx.ingress.kubernetes.io/proxy-buffering: "off"
nginx.ingress.kubernetes.io/proxy-request-buffering: "off"

# Client body buffer size for file uploads
nginx.ingress.kubernetes.io/client-body-buffer-size: "10m"

# In configuration snippet:
client_max_body_size 50m;
client_body_buffer_size 10m;
client_body_timeout 300s;
```

**Why these annotations are critical:**
- `proxy-body-size`: Sets maximum request body size (must match PHP upload limits)
- `proxy-request-buffering: off`: Prevents buffering issues with multipart form data
- `proxy-buffering: off`: Disables response buffering for better streaming
- `client-body-buffer-size`: Sets buffer size for request body
- Timeout settings: Prevents timeouts during large file uploads

### 3. Backend Config Creation
**File:** `/environment/staging/k8s-manifests/backend-config.yaml`

Created a proper BackendConfig resource for the GCP Load Balancer:
- Timeout configuration: 300 seconds
- Connection draining: 60 seconds
- Health check configuration
- Session affinity for sticky sessions

## Deployment Steps

### Step 1: Apply Backend Config
```bash
kubectl apply -f environment/staging/k8s-manifests/backend-config.yaml
```

### Step 2: Update Ingress Configuration
```bash
kubectl apply -f environment/staging/k8s-manifests/ingress.yaml
```

### Step 3: Verify Ingress Update
```bash
# Check ingress annotations
kubectl describe ingress laravel-ingress -n laravel-app

# Check backend config
kubectl describe backendconfig laravel-backend-config -n laravel-app
```

### Step 4: Check Load Balancer Update
```bash
# It may take 5-10 minutes for GCP Load Balancer to update
# Check the load balancer in GCP Console:
# https://console.cloud.google.com/net-services/loadbalancing/list/loadBalancers
```

### Step 5: Test File Upload
1. Upload a test PDF file with a descriptive name (e.g., "test-document-2024.pdf")
2. Check the logs:
   ```bash
   kubectl logs -f deployment/laravel-http -n laravel-app | grep "File upload processing"
   ```
3. Verify in the database that the media table has the correct filename
4. Verify in GCS bucket that the file is stored with the correct name

## Verification Checklist

- [ ] Backend config applied successfully
- [ ] Ingress updated with new annotations
- [ ] GCP Load Balancer shows updated configuration (wait 5-10 minutes)
- [ ] Test file upload shows correct filename in logs
- [ ] Media table has correct filename (not just `.pdf`)
- [ ] GCS bucket shows file with correct name
- [ ] File can be downloaded with correct name

## Debug Commands

### Check Pod Logs
```bash
# Real-time logs
kubectl logs -f deployment/laravel-http -n laravel-app

# Filter for upload logs
kubectl logs deployment/laravel-http -n laravel-app | grep -A 10 "File upload processing"
```

### Check Ingress Status
```bash
# Get ingress details
kubectl get ingress laravel-ingress -n laravel-app -o yaml

# Check ingress events
kubectl get events -n laravel-app --sort-by='.lastTimestamp' | grep ingress
```

### Check Backend Config Status
```bash
kubectl get backendconfig -n laravel-app
kubectl describe backendconfig laravel-backend-config -n laravel-app
```

### Test Upload with Curl
```bash
curl -X POST https://app.zyoshu.com/tenant/files/store \
  -H "Cookie: your-session-cookie" \
  -F "files[0]=@test-document.pdf" \
  -v
```

## Common Issues

### Issue 1: Still getting `.pdf` as filename
**Solution:** Check that the ingress has been updated properly:
```bash
kubectl describe ingress laravel-ingress -n laravel-app | grep -A 20 "Annotations"
```

### Issue 2: 413 Request Entity Too Large
**Solution:** Verify the annotations are applied and wait for load balancer update (5-10 mins).

### Issue 3: Timeout during upload
**Solution:** Check timeout settings in ingress annotations and backend config.

### Issue 4: Load balancer not updating
**Solution:** Force a reload by adding a dummy annotation and removing it:
```bash
kubectl annotate ingress laravel-ingress -n laravel-app reload=true
kubectl annotate ingress laravel-ingress -n laravel-app reload-
```

## Configuration Summary

### PHP Limits (Already Configured)
- `post_max_size`: 420M
- `upload_max_filesize`: 400M
- `max_execution_time`: 300s

### Ingress Limits (NEW)
- `proxy-body-size`: 50m
- `client-body-buffer-size`: 10m
- `timeout`: 300s

### Backend Config (NEW)
- `timeoutSec`: 300
- `connectionDraining`: 60s

## Notes

1. **GCP Load Balancer propagation**: Changes to ingress annotations can take 5-10 minutes to propagate to the GCP Load Balancer. Be patient.

2. **Nginx Ingress vs GCE Ingress**: The configuration uses `gce` ingress class, but some nginx annotations are still useful as they may be processed by nginx sidecar or similar components.

3. **File size limits**: The current configuration supports files up to 50MB through the ingress. PHP is configured to handle up to 400MB. Adjust as needed.

4. **Session affinity**: Backend config includes session affinity to ensure requests from the same client go to the same pod, which is important for multi-part uploads.

## Production Deployment

Before deploying to production:
1. Test thoroughly in staging
2. Monitor logs during the first few uploads
3. Update production ingress with same annotations
4. Consider adding alerts for upload failures
5. Document any environment-specific configurations

## Related Files

- Application: `/app/Actions/File/UploadFilesAction.php`
- Ingress: `/environment/staging/k8s-manifests/ingress.yaml`
- Backend Config: `/environment/staging/k8s-manifests/backend-config.yaml`
- PHP Config: `/deployment/php.ini`