# ==========================================================================
#  Compute Engine: load_balancer.tf (Load Balancer)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - HTTP(S) Load Balancer for Laravel application
#    - Backend service and health checks
#    - URL mapping and forwarding rules
# ==========================================================================

# --------------------------------------------------------------------------
#  Backend Service
# --------------------------------------------------------------------------
resource "google_compute_backend_service" "laravel_backend" {
  name                  = "laravel-backend-${var.environment[local.env]}"
  description           = "Backend service for Laravel application"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = 30
  enable_cdn            = false

  backend {
    group           = google_compute_instance_group_manager.laravel_group.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  health_checks = [google_compute_health_check.laravel_lb_health_check.id]

  depends_on = [google_compute_instance_group_manager.laravel_group]
}

# --------------------------------------------------------------------------
#  Health Check for Load Balancer
# --------------------------------------------------------------------------
resource "google_compute_health_check" "laravel_lb_health_check" {
  name               = "laravel-lb-health-check-${var.environment[local.env]}"
  check_interval_sec = 5
  timeout_sec        = 3
  healthy_threshold  = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = var.frankenphp_port
    request_path = "/health"
  }

  log_config {
    enable = true
  }
}

# --------------------------------------------------------------------------
#  URL Map
# --------------------------------------------------------------------------
resource "google_compute_url_map" "laravel_url_map" {
  name            = "laravel-url-map-${var.environment[local.env]}"
  description     = "URL map for Laravel application"
  default_service = google_compute_backend_service.laravel_backend.id

  # Multi-tenant routing configuration
  path_matcher {
    name            = "tenant-routing"
    default_service = google_compute_backend_service.laravel_backend.id

    # API routes for all tenants
    path_rule {
      paths   = ["/api/*"]
      service = google_compute_backend_service.laravel_backend.id
    }

    # Admin routes
    path_rule {
      paths   = ["/admin/*"]
      service = google_compute_backend_service.laravel_backend.id
    }

    # Health check endpoint
    path_rule {
      paths   = ["/health"]
      service = google_compute_backend_service.laravel_backend.id
    }

    # Static assets
    path_rule {
      paths   = ["/assets/*", "/css/*", "/js/*", "/images/*"]
      service = google_compute_backend_service.laravel_backend.id
    }
  }

  # Host-based routing for different domains
  dynamic "host_rule" {
    for_each = var.base_domain != "" ? [1] : []
    content {
      hosts        = ["${var.app_subdomain}.${var.base_domain}"]
      path_matcher = "tenant-routing"
    }
  }

  dynamic "host_rule" {
    for_each = var.base_domain != "" && var.wildcard_ssl ? [1] : []
    content {
      hosts        = ["*.${var.app_subdomain}.${var.base_domain}"]
      path_matcher = "tenant-routing"
    }
  }

  depends_on = [google_compute_backend_service.laravel_backend]
}

# --------------------------------------------------------------------------
#  HTTP Proxy
# --------------------------------------------------------------------------
resource "google_compute_target_http_proxy" "laravel_http_proxy" {
  name    = "laravel-http-proxy-${var.environment[local.env]}"
  url_map = google_compute_url_map.laravel_url_map.id

  depends_on = [google_compute_url_map.laravel_url_map]
}

# --------------------------------------------------------------------------
#  Reserved Static IP Address
# --------------------------------------------------------------------------
resource "google_compute_global_address" "laravel_ip" {
  name         = "laravel-ip-${var.environment[local.env]}"
  description  = "Static IP for Laravel application - Reserved for Cloudflare DNS"
  address_type = "EXTERNAL"
  
  # Prevent accidental deletion of the IP address
  lifecycle {
    prevent_destroy = true
  }
}

# --------------------------------------------------------------------------
#  SSL Certificate (Multi-tenant support)
# --------------------------------------------------------------------------
locals {
  # Generate domain list based on configuration
  ssl_domains = var.base_domain != "" ? (
    var.wildcard_ssl ? [
      "${var.app_subdomain}.${var.base_domain}",
      "*.${var.app_subdomain}.${var.base_domain}"
    ] : concat([
      "${var.app_subdomain}.${var.base_domain}"
    ], var.domain_names)
  ) : var.domain_names
}

resource "google_compute_managed_ssl_certificate" "laravel_ssl_cert" {
  count = var.enable_https && length(local.ssl_domains) > 0 ? 1 : 0

  name = "laravel-ssl-cert-${var.environment[local.env]}"

  managed {
    domains = local.ssl_domains
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --------------------------------------------------------------------------
#  HTTPS Proxy (optional)
# --------------------------------------------------------------------------
resource "google_compute_target_https_proxy" "laravel_https_proxy" {
  count = var.enable_https ? 1 : 0

  name             = "laravel-https-proxy-${var.environment[local.env]}"
  url_map          = google_compute_url_map.laravel_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.laravel_ssl_cert[0].id]

  depends_on = [
    google_compute_url_map.laravel_url_map,
    google_compute_managed_ssl_certificate.laravel_ssl_cert
  ]
}

# --------------------------------------------------------------------------
#  Global Forwarding Rule (HTTP) - Using Static IP
# --------------------------------------------------------------------------
resource "google_compute_global_forwarding_rule" "laravel_http_forwarding_rule" {
  name                  = "laravel-http-rule-${var.environment[local.env]}"
  target                = google_compute_target_http_proxy.laravel_http_proxy.id
  port_range           = "80"
  load_balancing_scheme = "EXTERNAL"
  ip_protocol          = "TCP"
  ip_address           = google_compute_global_address.laravel_ip.address

  depends_on = [
    google_compute_target_http_proxy.laravel_http_proxy,
    google_compute_global_address.laravel_ip
  ]
}

# --------------------------------------------------------------------------
#  Global Forwarding Rule (HTTPS) - Using Static IP
# --------------------------------------------------------------------------
resource "google_compute_global_forwarding_rule" "laravel_https_forwarding_rule" {
  count = var.enable_https ? 1 : 0

  name                  = "laravel-https-rule-${var.environment[local.env]}"
  target                = google_compute_target_https_proxy.laravel_https_proxy[0].id
  port_range           = "443"
  load_balancing_scheme = "EXTERNAL"
  ip_protocol          = "TCP"
  ip_address           = google_compute_global_address.laravel_ip.address

  depends_on = [
    google_compute_target_https_proxy.laravel_https_proxy,
    google_compute_global_address.laravel_ip
  ]
}
