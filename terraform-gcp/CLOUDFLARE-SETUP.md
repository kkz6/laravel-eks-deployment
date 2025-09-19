# Cloudflare Setup for Multi-Tenant Laravel Application

This guide explains how to configure Cloudflare DNS for your multi-tenant Laravel application deployed on GCP.

## Architecture Overview

```
Cloudflare DNS → GCP Load Balancer → FrankenPHP Laravel App

Domain Structure:
├── yourdomain.com (main domain in Cloudflare)
├── app.yourdomain.com (main application)
└── *.app.yourdomain.com (tenant subdomains)
    ├── tenant1.app.yourdomain.com
    ├── tenant2.app.yourdomain.com
    └── tenant3.app.yourdomain.com
```

## Prerequisites

1. **Domain in Cloudflare**: Your domain must be managed by Cloudflare
2. **GCP Load Balancer**: Deployed using this Terraform configuration
3. **SSL Certificate**: Google-managed SSL certificate for your domains

## Step 1: Deploy Infrastructure

First, deploy your infrastructure with the correct domain configuration:

### Update terraform.tfvars

```hcl
# Multi-tenant domain configuration
base_domain    = "yourdomain.com"        # Replace with your actual domain
app_subdomain  = "app"                   # Creates app.yourdomain.com
wildcard_ssl   = true                    # Enables *.app.yourdomain.com
enable_https   = true

# Enable tenant routing
tenant_routing_enabled = true
```

### Deploy the Infrastructure

```bash
cd terraform-gcp
./deploy.sh -p your-project-id -e staging -a apply
```

## Step 2: Get Load Balancer IP

After deployment, get the load balancer IP address:

```bash
cd terraform-gcp/environment/providers/gcp/infra/resources/compute-engine
terraform output load_balancer_ip
terraform output cloudflare_dns_records
```

Example output:

```
load_balancer_ip = "34.102.136.180"
cloudflare_dns_records = {
  "main_app" = {
    "name" = "app"
    "proxied" = true
    "type" = "A"
    "value" = "34.102.136.180"
  }
  "wildcard_tenants" = {
    "name" = "*"
    "proxied" = true
    "type" = "A"
    "value" = "34.102.136.180"
  }
}
```

## Step 3: Configure Cloudflare DNS

### Option A: Using Cloudflare Dashboard

1. **Login to Cloudflare Dashboard**

   - Go to [dash.cloudflare.com](https://dash.cloudflare.com)
   - Select your domain

2. **Add DNS Records**

   **Main Application Record:**

   - Type: `A`
   - Name: `app`
   - IPv4 Address: `YOUR_LOAD_BALANCER_IP`
   - Proxy Status: `Proxied` (orange cloud)

   **Wildcard for Tenants:**

   - Type: `A`
   - Name: `*.app`
   - IPv4 Address: `YOUR_LOAD_BALANCER_IP`
   - Proxy Status: `Proxied` (orange cloud)

### Option B: Using Cloudflare API

```bash
# Set your Cloudflare credentials
CLOUDFLARE_API_TOKEN="your_api_token"
ZONE_ID="your_zone_id"
LOAD_BALANCER_IP="34.102.136.180"  # Replace with your actual IP

# Add main app record
curl -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "A",
    "name": "app",
    "content": "'$LOAD_BALANCER_IP'",
    "ttl": 1,
    "proxied": true
  }'

# Add wildcard record for tenants
curl -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "A",
    "name": "*.app",
    "content": "'$LOAD_BALANCER_IP'",
    "ttl": 1,
    "proxied": true
  }'
```

### Option C: Using Terraform Cloudflare Provider (Advanced)

Add to your Terraform configuration:

```hcl
# terraform/cloudflare.tf
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "cloudflare_zone" "domain" {
  name = var.base_domain
}

resource "cloudflare_record" "app" {
  zone_id = data.cloudflare_zone.domain.id
  name    = var.app_subdomain
  value   = google_compute_global_address.laravel_ip.address
  type    = "A"
  proxied = true
}

resource "cloudflare_record" "wildcard_tenants" {
  count   = var.wildcard_ssl ? 1 : 0
  zone_id = data.cloudflare_zone.domain.id
  name    = "*.${var.app_subdomain}"
  value   = google_compute_global_address.laravel_ip.address
  type    = "A"
  proxied = true
}
```

## Step 4: Configure Cloudflare Settings

### SSL/TLS Settings

1. **Go to SSL/TLS → Overview**

   - Set encryption mode to **"Full (strict)"**
   - This ensures end-to-end encryption

2. **Go to SSL/TLS → Edge Certificates**
   - Enable **"Always Use HTTPS"**
   - Enable **"HTTP Strict Transport Security (HSTS)"**
   - Set **"Minimum TLS Version"** to 1.2 or higher

### Security Settings

1. **Go to Security → Settings**

   - Set **Security Level** to "Medium" or "High"
   - Enable **"Bot Fight Mode"**

2. **Go to Security → WAF**
   - Enable **"Web Application Firewall"**
   - Configure rules as needed

## Step 5: Verify SSL Certificate

Google Cloud will automatically provision SSL certificates for your domains. This may take 10-60 minutes.

Check certificate status:

```bash
# Check certificate provisioning status
gcloud compute ssl-certificates describe laravel-ssl-cert-staging \
  --global \
  --format="value(managed.status)"
```

Status should be `ACTIVE` when ready.

## Step 6: Test Your Setup

### Test Main Application

```bash
curl -H "Host: app.yourdomain.com" https://app.yourdomain.com/health
```

### Test Tenant Subdomains

```bash
curl -H "Host: tenant1.app.yourdomain.com" https://tenant1.app.yourdomain.com/health
curl -H "Host: tenant2.app.yourdomain.com" https://tenant2.app.yourdomain.com/health
```

### Browser Testing

- Visit `https://app.yourdomain.com`
- Visit `https://tenant1.app.yourdomain.com`
- Visit `https://tenant2.app.yourdomain.com`

## Laravel Multi-Tenant Configuration

Your Laravel application should handle tenant routing. Example middleware:

```php
// app/Http/Middleware/TenantMiddleware.php
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class TenantMiddleware
{
    public function handle(Request $request, Closure $next)
    {
        $host = $request->getHost();

        // Extract tenant from subdomain
        if (preg_match('/^([^.]+)\.app\.yourdomain\.com$/', $host, $matches)) {
            $tenant = $matches[1];

            // Set tenant context
            app()->instance('tenant', $tenant);
            config(['app.tenant' => $tenant]);
        }

        return $next($request);
    }
}
```

Register in `app/Http/Kernel.php`:

```php
protected $middlewareGroups = [
    'web' => [
        // ... other middleware
        \App\Http\Middleware\TenantMiddleware::class,
    ],
];
```

## Troubleshooting

### DNS Propagation

- DNS changes can take up to 24 hours to propagate globally
- Use `dig` or online tools to check DNS propagation
- Clear your local DNS cache if needed

### SSL Certificate Issues

- Google-managed certificates can take 10-60 minutes to provision
- Ensure DNS records are correct before certificate provisioning
- Check certificate status in GCP Console

### Cloudflare Proxy Issues

- If using Cloudflare proxy (orange cloud), ensure SSL mode is "Full (strict)"
- Disable proxy temporarily for testing if needed
- Check Cloudflare firewall rules

### Application Issues

- Verify FrankenPHP is configured for multiple domains
- Check Laravel logs for tenant routing issues
- Ensure database connections work for all tenants

## Advanced Configuration

### Custom SSL Certificates

If you prefer to use Cloudflare's SSL certificates instead of Google-managed:

1. Set `enable_https = false` in Terraform
2. Use Cloudflare's "Flexible" SSL mode
3. Configure Cloudflare SSL certificates

### Rate Limiting

Configure rate limiting per tenant in Cloudflare:

1. Go to **Security → WAF → Rate limiting rules**
2. Create rules based on subdomain patterns
3. Set different limits for different tenant tiers

### Analytics and Monitoring

- Enable Cloudflare Analytics for traffic insights
- Set up Google Cloud Monitoring for application metrics
- Configure alerts for SSL certificate expiration

## Cost Considerations

- **Cloudflare**: Free tier supports basic DNS and proxy features
- **GCP Load Balancer**: ~$18/month + traffic costs
- **SSL Certificates**: Free with Google-managed certificates
- **Compute Engine**: Based on instance type and usage

## Security Best Practices

1. **Use HTTPS everywhere**: Force HTTPS redirects
2. **Enable HSTS**: Prevent SSL stripping attacks
3. **Configure CSP**: Content Security Policy headers
4. **Rate limiting**: Protect against abuse
5. **WAF rules**: Filter malicious traffic
6. **Monitor logs**: Set up alerts for suspicious activity

This setup provides a robust, scalable foundation for your multi-tenant Laravel application with proper SSL termination and CDN benefits from Cloudflare.
