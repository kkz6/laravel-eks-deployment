# ==========================================================================
#  GKE: redis-vm.tf (Redis VM Instance)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Dedicated VM for Redis
#    - Cost-effective alternative to Memorystore
#    - Persistent storage and backup
# ==========================================================================

# --------------------------------------------------------------------------
#  Get Custom VPC Configuration (already defined in gke-cluster.tf)
# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
#  Redis VM Instance
# --------------------------------------------------------------------------
resource "google_compute_instance" "redis_vm" {
  name         = "laravel-redis-${var.environment[local.env]}"
  machine_type = var.redis_machine_type
  zone         = var.gcp_zone

  # Boot disk
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.redis_disk_size
      type  = "pd-standard"
    }
  }

  # Network interface - Using custom VPC for production
  network_interface {
    network    = data.terraform_remote_state.vpc.outputs.vpc_name
    subnetwork = data.terraform_remote_state.vpc.outputs.private_subnet_name
    
    # No external IP for VPC-only access (NAT gateway provides internet access)
  }

  # Service account
  service_account {
    email  = google_service_account.redis_vm_sa.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write"
    ]
  }

  # Metadata and startup script
  metadata = {
    startup-script = templatefile("${path.module}/scripts/setup-redis.sh", {
      redis_version = var.redis_version
      environment   = var.environment[local.env]
    })
  }

  # Network tags for VPC firewall rules
  tags = ["redis-server", "ssh-allowed"]

  # Labels
  labels = merge(local.labels, {
    component = "redis"
    purpose   = "laravel-queue"
  })

  # Lifecycle
  lifecycle {
    create_before_destroy = true
  }

  depends_on = [google_service_account.redis_vm_sa]
}

# --------------------------------------------------------------------------
#  Service Account for Redis VM
# --------------------------------------------------------------------------
resource "google_service_account" "redis_vm_sa" {
  account_id   = "redis-vm-${var.environment[local.env]}"
  display_name = "Redis VM Service Account"
  description  = "Service account for Redis VM instance"
}

resource "google_project_iam_member" "redis_vm_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.redis_vm_sa.email}"
}

resource "google_project_iam_member" "redis_vm_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.redis_vm_sa.email}"
}

# --------------------------------------------------------------------------
#  Firewall Rule for Redis Access from GKE
# --------------------------------------------------------------------------
resource "google_compute_firewall" "allow_redis_from_gke" {
  name    = "laravel-allow-redis-from-gke-${var.environment[local.env]}"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["6379"]
  }

  # Allow access from GKE nodes
  source_tags = ["laravel-gke-node"]
  target_tags = ["laravel-redis"]

  depends_on = [google_compute_instance.redis_vm]
}

# --------------------------------------------------------------------------
#  Persistent Disk for Redis Data
# --------------------------------------------------------------------------
resource "google_compute_disk" "redis_data" {
  name = "laravel-redis-data-${var.environment[local.env]}"
  type = "pd-standard"
  zone = var.gcp_zone
  size = 10

  labels = merge(local.labels, {
    component = "redis-storage"
  })

  # Lifecycle
  lifecycle {
    prevent_destroy = true
  }
}

# Attach the disk to Redis VM
resource "google_compute_attached_disk" "redis_data_attachment" {
  disk     = google_compute_disk.redis_data.id
  instance = google_compute_instance.redis_vm.id

  depends_on = [
    google_compute_disk.redis_data,
    google_compute_instance.redis_vm
  ]
}
