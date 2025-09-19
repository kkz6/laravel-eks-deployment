# FrankenPHP Laravel Deployment Guide

This guide explains how to deploy Laravel applications using FrankenPHP on Google Cloud Platform.

## What is FrankenPHP?

FrankenPHP is a modern PHP application server written in Go. It's designed to be:

- **Fast**: Built on top of Caddy web server
- **Simple**: No need for separate Nginx/Apache configuration
- **Modern**: Supports HTTP/2, HTTP/3, and automatic HTTPS
- **Efficient**: Built-in worker mode for better performance

## Key Differences from Traditional Setup

### Traditional (PHP-FPM + Nginx)

```
Internet → Load Balancer → Nginx → PHP-FPM → Laravel
```

### FrankenPHP

```
Internet → Load Balancer → FrankenPHP → Laravel
```

## Configuration for FrankenPHP

### 1. Docker Image Requirements

Your FrankenPHP-based Laravel Docker image should:

```dockerfile
# Example Dockerfile for FrankenPHP Laravel
FROM dunglas/frankenphp:latest

# Copy Laravel application
COPY . /app
WORKDIR /app

# Install dependencies
RUN composer install --no-dev --optimize-autoloader

# Set permissions
RUN chown -R www-data:www-data /app/storage /app/bootstrap/cache

# Expose port
EXPOSE 80 443

# Configure FrankenPHP
ENV FRANKENPHP_CONFIG="worker ./public/frankenphp-worker.php"
ENV SERVER_NAME=":80"

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s \
    CMD curl -f http://localhost/health || exit 1
```

### 2. Laravel Configuration

Add a health check route in your Laravel application:

```php
// routes/web.php
Route::get('/health', function () {
    return response()->json([
        'status' => 'healthy',
        'timestamp' => now()->toISOString(),
        'environment' => app()->environment(),
    ]);
});
```

### 3. FrankenPHP Worker (Optional)

For better performance, create `public/frankenphp-worker.php`:

```php
<?php

use App\Kernel;
use Symfony\Component\HttpFoundation\Request;

require_once dirname(__DIR__).'/vendor/autoload_runtime.php';

return function (array $context) {
    return new Kernel($context['APP_ENV'], (bool) $context['APP_DEBUG']);
};
```

## Deployment Variables

Configure these variables in your `terraform.tfvars`:

```hcl
# FrankenPHP Configuration
docker_image     = "ghcr.io/your-username/your-laravel-app:latest"
frankenphp_port  = 80

# GitHub Container Registry Authentication
github_username  = "your-github-username"
github_token     = "ghp_your_personal_access_token"

# Laravel Configuration
app_env         = "production"
app_debug       = false
app_key         = "base64:your-app-key"
```

## GitHub Actions Build Example

```yaml
name: Build FrankenPHP Laravel Image

on:
  push:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile.frankenphp
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
```

## Performance Benefits

### Traditional Setup

- Multiple processes: Nginx + PHP-FPM
- Request overhead: HTTP proxy between Nginx and PHP-FPM
- Memory usage: Separate processes for web server and PHP

### FrankenPHP

- Single process: Integrated web server and PHP runtime
- Direct execution: No proxy overhead
- Worker mode: Persistent application state
- Lower memory footprint

## Monitoring and Debugging

### Container Logs

```bash
# View FrankenPHP logs
docker-compose logs -f laravel

# Monitor container status
docker-compose ps
```

### Health Checks

```bash
# Check application health
curl http://your-load-balancer-ip/health

# Check FrankenPHP metrics (if enabled)
curl http://your-load-balancer-ip/metrics
```

### Performance Monitoring

```bash
# Container resource usage
docker stats laravel-frankenphp

# Application performance
curl -w "@curl-format.txt" -o /dev/null -s http://your-app/
```

## Troubleshooting

### Common Issues

1. **Container won't start**

   ```bash
   # Check container logs
   docker-compose logs laravel

   # Check if image exists and is accessible
   docker pull ghcr.io/your-username/your-app:latest
   ```

2. **GitHub authentication fails**

   ```bash
   # Test GitHub token
   echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin
   ```

3. **Health check failures**
   - Ensure `/health` route exists in Laravel
   - Check if FrankenPHP is listening on correct port
   - Verify firewall rules allow health check traffic

### Debug Mode

Enable debug mode for troubleshooting:

```hcl
# In terraform.tfvars
app_debug = true
app_env   = "staging"
```

## Security Considerations

1. **Environment Variables**: Store sensitive data in Terraform variables, not in Docker image
2. **GitHub Token**: Use tokens with minimal required permissions (`read:packages`)
3. **Health Endpoint**: Consider adding basic authentication for production
4. **HTTPS**: Enable HTTPS for production deployments

## Migration from PHP-FPM

If migrating from a PHP-FPM setup:

1. **Update Dockerfile**: Replace PHP-FPM base with FrankenPHP
2. **Remove Nginx config**: FrankenPHP handles HTTP directly
3. **Update health checks**: Point to FrankenPHP port (usually 80)
4. **Test thoroughly**: Verify all Laravel features work with FrankenPHP
5. **Monitor performance**: Compare metrics with previous setup

## Resources

- [FrankenPHP Documentation](https://frankenphp.dev/)
- [FrankenPHP Docker Images](https://hub.docker.com/r/dunglas/frankenphp)
- [Laravel Performance Tips](https://laravel.com/docs/deployment#optimization)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
