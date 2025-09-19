# ==========================================================================
#  Core: vpc.tf (Virtual Private Cloud)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - VPC Network
#    - Public & Private Subnets
#    - Cloud Router & NAT Gateway
# ==========================================================================

# --------------------------------------------------------------------------
#  VPC Network
# --------------------------------------------------------------------------
resource "google_compute_network" "laravel_vpc" {
  name                    = "laravel-vpc-${var.environment[local.env]}"
  auto_create_subnetworks = false
  mtu                     = 1460

  # Add labels
  project = var.project_id

  depends_on = []
}

# --------------------------------------------------------------------------
#  Public Subnets
# --------------------------------------------------------------------------
resource "google_compute_subnetwork" "public_subnets" {
  count = length(var.public_subnet_cidrs)

  name          = "laravel-public-subnet-${count.index + 1}-${var.environment[local.env]}"
  ip_cidr_range = var.public_subnet_cidrs[count.index]
  region        = var.gcp_region
  network       = google_compute_network.laravel_vpc.id

  # Enable private Google access
  private_ip_google_access = true

  depends_on = [google_compute_network.laravel_vpc]
}

# --------------------------------------------------------------------------
#  Private Subnets
# --------------------------------------------------------------------------
resource "google_compute_subnetwork" "private_subnets" {
  count = length(var.private_subnet_cidrs)

  name          = "laravel-private-subnet-${count.index + 1}-${var.environment[local.env]}"
  ip_cidr_range = var.private_subnet_cidrs[count.index]
  region        = var.gcp_region
  network       = google_compute_network.laravel_vpc.id

  # Enable private Google access
  private_ip_google_access = true

  depends_on = [google_compute_network.laravel_vpc]
}

# --------------------------------------------------------------------------
#  Cloud Router for NAT Gateway
# --------------------------------------------------------------------------
resource "google_compute_router" "laravel_router" {
  name    = "laravel-router-${var.environment[local.env]}"
  region  = var.gcp_region
  network = google_compute_network.laravel_vpc.id

  depends_on = [google_compute_network.laravel_vpc]
}

# --------------------------------------------------------------------------
#  Cloud NAT Gateway
# --------------------------------------------------------------------------
resource "google_compute_router_nat" "laravel_nat" {
  name                               = "laravel-nat-${var.environment[local.env]}"
  router                             = google_compute_router.laravel_router.name
  region                             = var.gcp_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  depends_on = [google_compute_router.laravel_router]
}
