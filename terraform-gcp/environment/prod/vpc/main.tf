# ==========================================================================
#  VPC Configuration
# --------------------------------------------------------------------------
#  Custom VPC for Laravel deployment with proper network segmentation
# ==========================================================================

# --------------------------------------------------------------------------
#  Local Variables
# --------------------------------------------------------------------------
locals {
  env = terraform.workspace == "default" ? "stg" : terraform.workspace
  
  labels = {
    project       = "laravel-gcp-deployment"
    environment   = local.env
    department    = var.department
    terraform     = "true"
    component     = "vpc"
  }
}

# --------------------------------------------------------------------------
#  Custom VPC Network
# --------------------------------------------------------------------------
resource "google_compute_network" "laravel_vpc" {
  name                    = "laravel-vpc-${local.env}"
  auto_create_subnetworks = false
  mtu                     = 1460
  
  description = "Custom VPC for Laravel ${local.env} environment"
  
  labels = local.labels
}

# --------------------------------------------------------------------------
#  Public Subnet (for NAT Gateway, Load Balancers)
# --------------------------------------------------------------------------
resource "google_compute_subnetwork" "public_subnet" {
  name          = "laravel-public-subnet-${local.env}"
  ip_cidr_range = var.public_subnet_cidr
  network       = google_compute_network.laravel_vpc.id
  region        = var.gcp_region
  
  description = "Public subnet for NAT Gateway and Load Balancers"
  
  # Enable private Google access for instances without external IPs
  private_ip_google_access = true
}

# --------------------------------------------------------------------------
#  Private Subnet (for GKE, Redis VM, Cloud SQL)
# --------------------------------------------------------------------------
resource "google_compute_subnetwork" "private_subnet" {
  name          = "laravel-private-subnet-${local.env}"
  ip_cidr_range = var.private_subnet_cidr
  network       = google_compute_network.laravel_vpc.id
  region        = var.gcp_region
  
  description = "Private subnet for GKE cluster, Redis VM, and Cloud SQL"
  
  # Enable private Google access
  private_ip_google_access = true
  
  # Secondary IP ranges for GKE
  secondary_ip_range {
    range_name    = "gke-pods-${local.env}"
    ip_cidr_range = var.gke_pod_cidr
  }
  
  secondary_ip_range {
    range_name    = "gke-services-${local.env}"
    ip_cidr_range = var.gke_service_cidr
  }
}

# --------------------------------------------------------------------------
#  Cloud Router for NAT Gateway
# --------------------------------------------------------------------------
resource "google_compute_router" "laravel_router" {
  name    = "laravel-router-${local.env}"
  region  = var.gcp_region
  network = google_compute_network.laravel_vpc.id
  
  description = "Router for NAT Gateway"
}

# --------------------------------------------------------------------------
#  NAT Gateway (for outbound internet access from private instances)
# --------------------------------------------------------------------------
resource "google_compute_router_nat" "laravel_nat" {
  name                               = "laravel-nat-${local.env}"
  router                            = google_compute_router.laravel_router.name
  region                            = var.gcp_region
  nat_ip_allocate_option            = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  
  subnetwork {
    name                    = google_compute_subnetwork.private_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
  
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# --------------------------------------------------------------------------
#  Firewall Rules
# --------------------------------------------------------------------------

# Allow internal communication within VPC
resource "google_compute_firewall" "allow_internal" {
  name    = "laravel-allow-internal-${local.env}"
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
  
  source_ranges = [
    var.public_subnet_cidr,
    var.private_subnet_cidr,
    var.gke_pod_cidr,
    var.gke_service_cidr
  ]
  
  description = "Allow internal communication within Laravel VPC"
  
  labels = local.labels
}

# Allow SSH from specific IP ranges (for debugging)
resource "google_compute_firewall" "allow_ssh" {
  name    = "laravel-allow-ssh-${local.env}"
  network = google_compute_network.laravel_vpc.name
  
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  
  source_ranges = var.allowed_ssh_ranges
  target_tags   = ["ssh-allowed"]
  
  description = "Allow SSH access for debugging"
  
  labels = local.labels
}

# Allow HTTP/HTTPS from Load Balancer
resource "google_compute_firewall" "allow_lb_health_check" {
  name    = "laravel-allow-lb-health-check-${local.env}"
  network = google_compute_network.laravel_vpc.name
  
  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080", "8000"]
  }
  
  # Google Cloud Load Balancer health check ranges
  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22"
  ]
  
  target_tags = ["http-server"]
  
  description = "Allow health checks from Google Cloud Load Balancer"
  
  labels = local.labels
}

# Allow GKE Pods to access Cloud SQL
resource "google_compute_firewall" "allow_gke_to_cloudsql" {
  name    = "laravel-allow-gke-to-cloudsql-${local.env}"
  network = google_compute_network.laravel_vpc.name
  
  allow {
    protocol = "tcp"
    ports    = ["3306"]
  }
  
  source_ranges = [var.gke_pod_cidr]
  target_tags   = ["cloudsql"]
  
  description = "Allow GKE pods to access Cloud SQL"
  
  labels = local.labels
}

# Allow GKE Pods to access Redis
resource "google_compute_firewall" "allow_gke_to_redis" {
  name    = "laravel-allow-gke-to-redis-${local.env}"
  network = google_compute_network.laravel_vpc.name
  
  allow {
    protocol = "tcp"
    ports    = ["6379"]
  }
  
  source_ranges = [var.gke_pod_cidr]
  target_tags   = ["redis-server"]
  
  description = "Allow GKE pods to access Redis VM"
  
  labels = local.labels
}
