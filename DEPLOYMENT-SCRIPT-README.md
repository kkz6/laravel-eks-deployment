# Laravel Deployment Script

## Overview

The `deploy-laravel.sh` script provides a convenient way to deploy and redeploy your Laravel application pods on Kubernetes with the latest Docker image.

## Features

✅ **Automated Deployment** - Restart all Laravel pods with latest image  
✅ **Health Checks** - Verify Laravel and GCS connectivity  
✅ **Status Monitoring** - Check current deployment status  
✅ **Safety Checks** - Verify kubectl connectivity and namespace  
✅ **Rollout Monitoring** - Wait for deployments to complete  
✅ **Colored Output** - Easy to read status messages  

## Usage

### Quick Deployment
```bash
./deploy-laravel.sh
```

### Check Status Only
```bash
./deploy-laravel.sh --status
```

### Custom Namespace
```bash
./deploy-laravel.sh --namespace my-namespace
```

### Custom Timeout
```bash
./deploy-laravel.sh --timeout 600s
```

### Help
```bash
./deploy-laravel.sh --help
```

## What the Script Does

### 1. **Pre-flight Checks**
- Verifies kubectl is installed and connected
- Checks if the target namespace exists
- Shows current pod and deployment status

### 2. **Deployment Process**
- Restarts all three Laravel deployments:
  - `laravel-http` (Web server)
  - `laravel-scheduler` (Cron jobs)
  - `laravel-horizon` (Queue worker)
- Waits for rollouts to complete
- Monitors deployment progress

### 3. **Post-deployment Verification**
- Lists new pod names and status
- Verifies Docker image versions
- Checks GCS environment variables
- Tests Laravel application health
- Tests GCS connectivity

### 4. **Health Checks**
- Runs `php artisan --version` to verify Laravel
- Tests Google Cloud Storage client connectivity
- Reports success/failure status

## Output Example

```
============================================
  Laravel Application Deployment
============================================
Namespace: laravel-app
Deployments: laravel-http laravel-scheduler laravel-horizon

✓ kubectl connectivity verified
✓ Namespace 'laravel-app' exists

Current Pod Status:
NAME                                 READY   STATUS    RESTARTS   AGE
laravel-http-c66d5c6b5-sxxgz         1/1     Running   0          9m21s
laravel-scheduler-75c4c879b8-dwzvj   1/1     Running   1          9m19s
laravel-horizon-694f4dd47-fnnnm      1/1     Running   0          9m20s

Continue with deployment? [y/N]: y

Restarting Laravel deployments...
deployment.apps/laravel-http restarted
deployment.apps/laravel-scheduler restarted
deployment.apps/laravel-horizon restarted

✓ laravel-http rollout completed
✓ laravel-scheduler rollout completed
✓ laravel-horizon rollout completed

✓ Laravel is running: Laravel Framework 10.x
✓ GCS connectivity working

============================================
  Laravel Deployment Completed Successfully!
============================================
```

## Configuration

### Default Settings
- **Namespace**: `laravel-app`
- **Timeout**: `300s` (5 minutes)
- **Deployments**: `laravel-http`, `laravel-scheduler`, `laravel-horizon`

### Customization
You can modify the script variables at the top:

```bash
NAMESPACE="laravel-app"
DEPLOYMENTS=("laravel-http" "laravel-scheduler" "laravel-horizon")
TIMEOUT="300s"
```

## Troubleshooting

### Common Issues

1. **kubectl not found**
   - Install kubectl: `gcloud components install kubectl`
   - Ensure it's in your PATH

2. **Cannot connect to cluster**
   - Run: `gcloud container clusters get-credentials CLUSTER_NAME --zone ZONE`
   - Verify: `kubectl cluster-info`

3. **Namespace doesn't exist**
   - Create namespace: `kubectl create namespace laravel-app`
   - Or use existing namespace with `-n` flag

4. **Deployment not found**
   - Check deployment names: `kubectl get deployments -n laravel-app`
   - Update script if deployment names differ

5. **Rollout timeout**
   - Increase timeout: `./deploy-laravel.sh -t 600s`
   - Check pod logs: `kubectl logs -f deployment/laravel-http -n laravel-app`

### Debugging Commands

```bash
# Check pod status
kubectl get pods -n laravel-app

# Check deployment status
kubectl get deployments -n laravel-app

# View pod logs
kubectl logs -f deployment/laravel-http -n laravel-app

# Describe deployment
kubectl describe deployment laravel-http -n laravel-app

# Check rollout history
kubectl rollout history deployment/laravel-http -n laravel-app
```

## Integration with CI/CD

You can integrate this script with your CI/CD pipeline:

```bash
# In your deployment pipeline
./deploy-laravel.sh --timeout 600s
```

Or for automated deployments without confirmation:

```bash
# Modify the script to skip confirmation in CI mode
echo "y" | ./deploy-laravel.sh
```

## Security Notes

- The script uses your current kubectl context
- Ensure you're connected to the correct cluster
- Review the confirmation prompt before proceeding
- Monitor deployment logs for any issues

## Next Steps

After successful deployment:

1. **Test Application**: Verify your Laravel app is working
2. **Monitor Logs**: Check for any errors in pod logs
3. **Run Tests**: Execute your application test suite
4. **Check GCS**: Verify multi-tenant bucket operations work
5. **Performance**: Monitor resource usage and performance

---

**Happy Deploying! 🚀**
