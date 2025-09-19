# ==========================================================================
#  Core: firewall.tf (Firewall Rules)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Firewall rules for Laravel application
#    - HTTP, HTTPS, SSH access
#    - Database access rules
# ==========================================================================

# --------------------------------------------------------------------------
#  Allow HTTP Traffic
# --------------------------------------------------------------------------
resource "google_compute_firewall" "allow_http" {
  name    = "laravel-allow-http-${var.environment[local.env]}"
  network = google_compute_network.laravel_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["laravel-web"]

  depends_on = [google_compute_network.laravel_vpc]
}

# --------------------------------------------------------------------------
#  Allow HTTPS Traffic
# --------------------------------------------------------------------------
resource "google_compute_firewall" "allow_https" {
  name    = "laravel-allow-https-${var.environment[local.env]}"
  network = google_compute_network.laravel_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["laravel-web"]

  depends_on = [google_compute_network.laravel_vpc]
}

# --------------------------------------------------------------------------
#  Allow SSH Access
# --------------------------------------------------------------------------
resource "google_compute_firewall" "allow_ssh" {
  name    = "laravel-allow-ssh-${var.environment[local.env]}"
  network = google_compute_network.laravel_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["laravel-ssh"]

  depends_on = [google_compute_network.laravel_vpc]
}

# --------------------------------------------------------------------------
#  Allow FrankenPHP Port (for internal communication)
# --------------------------------------------------------------------------
resource "google_compute_firewall" "allow_frankenphp_app" {
  name    = "laravel-allow-frankenphp-${var.environment[local.env]}"
  network = google_compute_network.laravel_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["10.0.0.0/16"]
  target_tags   = ["laravel-app"]

  depends_on = [google_compute_network.laravel_vpc]
}

# --------------------------------------------------------------------------
#  Allow Database Access (Internal)
# --------------------------------------------------------------------------
resource "google_compute_firewall" "allow_database" {
  name    = "laravel-allow-database-${var.environment[local.env]}"
  network = google_compute_network.laravel_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["3306", "5432"]
  }

  source_ranges = ["10.0.0.0/16"]
  target_tags   = ["laravel-database"]

  depends_on = [google_compute_network.laravel_vpc]
}

# --------------------------------------------------------------------------
#  Allow Load Balancer Health Checks
# --------------------------------------------------------------------------
resource "google_compute_firewall" "allow_health_checks" {
  name    = "laravel-allow-health-checks-${var.environment[local.env]}"
  network = google_compute_network.laravel_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  # Google Cloud Load Balancer health check ranges
  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16"
  ]

  target_tags = ["laravel-web", "laravel-app"]

  depends_on = [google_compute_network.laravel_vpc]
}

# --------------------------------------------------------------------------
#  Internal Communication
# --------------------------------------------------------------------------
resource "google_compute_firewall" "allow_internal" {
  name    = "laravel-allow-internal-${var.environment[local.env]}"
  network = google_compute_network.laravel_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/16"]

  depends_on = [google_compute_network.laravel_vpc]
}
