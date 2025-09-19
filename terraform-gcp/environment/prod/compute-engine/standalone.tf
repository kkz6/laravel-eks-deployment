# ==========================================================================
#  Compute Engine: standalone.tf (Standalone Configuration)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Standalone configuration that doesn't depend on remote state
#    - Uses default VPC and creates minimal firewall rules
#    - For quick deployment without core infrastructure
# ==========================================================================

# --------------------------------------------------------------------------
#  Default VPC Firewall Rules (when not using custom VPC)
# --------------------------------------------------------------------------
resource "google_compute_firewall" "allow_http_default" {
  count   = var.use_remote_state ? 0 : 1
  name    = "laravel-allow-http-default-${var.environment[local.env]}"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["laravel-web"]
}

resource "google_compute_firewall" "allow_https_default" {
  count   = var.use_remote_state ? 0 : 1
  name    = "laravel-allow-https-default-${var.environment[local.env]}"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["laravel-web"]
}

resource "google_compute_firewall" "allow_ssh_default" {
  count   = var.use_remote_state ? 0 : 1
  name    = "laravel-allow-ssh-default-${var.environment[local.env]}"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["laravel-ssh"]
}

resource "google_compute_firewall" "allow_frankenphp_default" {
  count   = var.use_remote_state ? 0 : 1
  name    = "laravel-allow-frankenphp-default-${var.environment[local.env]}"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = [var.frankenphp_port]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["laravel-app"]
}

resource "google_compute_firewall" "allow_health_checks_default" {
  count   = var.use_remote_state ? 0 : 1
  name    = "laravel-allow-health-checks-default-${var.environment[local.env]}"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443", var.frankenphp_port]
  }

  # Google Cloud Load Balancer health check ranges
  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16"
  ]

  target_tags = ["laravel-web", "laravel-app"]
}
