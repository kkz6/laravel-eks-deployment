# ==========================================================================
#  GKE: cloud-nat.tf (Cloud NAT Configuration)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Cloud Router for NAT gateway
#    - Static external IP for consistent outbound connections
#    - Cloud NAT gateway for Laravel pods IP authentication
# ==========================================================================

# --------------------------------------------------------------------------
#  Static External IP for NAT Gateway
# --------------------------------------------------------------------------
resource "google_compute_address" "nat_ip" {
  name   = "laravel-nat-ip-${var.environment[local.env]}"
  region = var.gcp_region
  
  description = "Static IP for Cloud NAT - Laravel ${var.environment[local.env]} environment"
}

# --------------------------------------------------------------------------
#  Cloud Router for NAT Gateway
# --------------------------------------------------------------------------
resource "google_compute_router" "nat_router" {
  name    = "laravel-nat-router-${var.environment[local.env]}"
  region  = var.gcp_region
  network = "default" # Using default VPC for staging
  
  description = "Cloud Router for NAT Gateway - Laravel ${var.environment[local.env]} environment"
}

# --------------------------------------------------------------------------
#  Cloud NAT Gateway
# --------------------------------------------------------------------------
resource "google_compute_router_nat" "nat_gateway" {
  name   = "laravel-nat-gateway-${var.environment[local.env]}"
  router = google_compute_router.nat_router.name
  region = var.gcp_region

  # NAT all subnet IP ranges (includes GKE pods)
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  
  # Use manual IP allocation with our static IP
  nat_ip_allocate_option = "MANUAL_ONLY"
  nat_ips                = [google_compute_address.nat_ip.self_link]

  # Logging configuration (optional, for debugging)
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  # Enable endpoint independent mapping for better compatibility
  enable_endpoint_independent_mapping = false
  
  # Port allocation settings for better resource utilization
  min_ports_per_vm = 64
  max_ports_per_vm = 512

  depends_on = [
    google_compute_router.nat_router,
    google_compute_address.nat_ip
  ]
}
