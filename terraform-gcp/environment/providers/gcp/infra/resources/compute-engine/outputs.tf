# ==========================================================================
#  Compute Engine: outputs.tf (Output Terraform)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Return value terraform output
# ==========================================================================

# --------------------------------------------------------------------------
#  Load Balancer Outputs
# --------------------------------------------------------------------------
output "load_balancer_ip" {
  description = "External IP address of the load balancer (STATIC - Safe for DNS)"
  value       = google_compute_global_address.laravel_ip.address
}

output "static_ip_reserved" {
  description = "Whether the IP address is reserved (not ephemeral)"
  value       = true
}

output "static_ip_name" {
  description = "Name of the reserved static IP address"
  value       = google_compute_global_address.laravel_ip.name
}

output "load_balancer_url" {
  description = "URL of the Laravel application"
  value       = "http://${google_compute_global_address.laravel_ip.address}"
}

output "load_balancer_https_url" {
  description = "HTTPS URL of the Laravel application (if HTTPS is enabled)"
  value       = var.enable_https ? "https://${google_compute_global_address.laravel_ip.address}" : null
}

output "primary_domain_url" {
  description = "Primary domain URL for the application"
  value       = var.base_domain != "" ? "https://${var.app_subdomain}.${var.base_domain}" : null
}

output "wildcard_domain_example" {
  description = "Example tenant subdomain URL"
  value       = var.base_domain != "" && var.wildcard_ssl ? "https://tenant1.${var.app_subdomain}.${var.base_domain}" : null
}

# --------------------------------------------------------------------------
#  Instance Group Outputs
# --------------------------------------------------------------------------
output "instance_group_manager" {
  description = "Instance group manager name"
  value       = google_compute_instance_group_manager.laravel_group.name
}

output "instance_group_size" {
  description = "Current size of the instance group"
  value       = google_compute_instance_group_manager.laravel_group.target_size
}

# --------------------------------------------------------------------------
#  Service Account Outputs
# --------------------------------------------------------------------------
output "service_account_email" {
  description = "Email of the service account"
  value       = google_service_account.laravel_compute_sa.email
}

# --------------------------------------------------------------------------
#  Health Check Outputs
# --------------------------------------------------------------------------
output "health_check_name" {
  description = "Name of the health check"
  value       = google_compute_health_check.laravel_health_check.name
}

output "lb_health_check_name" {
  description = "Name of the load balancer health check"
  value       = google_compute_health_check.laravel_lb_health_check.name
}

# --------------------------------------------------------------------------
#  Backend Service Outputs
# --------------------------------------------------------------------------
output "backend_service_name" {
  description = "Name of the backend service"
  value       = google_compute_backend_service.laravel_backend.name
}

# --------------------------------------------------------------------------
#  SSL Certificate Outputs (if HTTPS enabled)
# --------------------------------------------------------------------------
output "ssl_certificate_name" {
  description = "Name of the SSL certificate (if HTTPS enabled)"
  value       = var.enable_https ? google_compute_managed_ssl_certificate.laravel_ssl_cert[0].name : null
}

output "ssl_certificate_domains" {
  description = "Domains covered by the SSL certificate (if HTTPS enabled)"
  value       = var.enable_https && length(local.ssl_domains) > 0 ? google_compute_managed_ssl_certificate.laravel_ssl_cert[0].managed[0].domains : null
}

# --------------------------------------------------------------------------
#  Multi-Tenant Configuration Outputs
# --------------------------------------------------------------------------
output "base_domain" {
  description = "Base domain configured for the application"
  value       = var.base_domain
}

output "app_subdomain" {
  description = "Application subdomain"
  value       = var.app_subdomain
}

output "tenant_routing_enabled" {
  description = "Whether tenant routing is enabled"
  value       = var.tenant_routing_enabled
}

output "cloudflare_dns_records" {
  description = "DNS records to create in Cloudflare"
  value = var.base_domain != "" ? {
    main_app = {
      type    = "A"
      name    = var.app_subdomain
      value   = google_compute_global_address.laravel_ip.address
      proxied = true
    }
    wildcard_tenants = var.wildcard_ssl ? {
      type    = "A"
      name    = "*"
      value   = google_compute_global_address.laravel_ip.address
      proxied = true
    } : null
  } : null
}

# --------------------------------------------------------------------------
#  Environment Outputs
# --------------------------------------------------------------------------
output "environment" {
  description = "Environment name"
  value       = var.environment[local.env]
}

output "region" {
  description = "GCP region"
  value       = var.gcp_region
}

output "zone" {
  description = "GCP zone"
  value       = var.gcp_zone
}
