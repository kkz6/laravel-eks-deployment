# ==========================================================================
#  Compute Engine: compute.tf (VM Instances)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - VM instances for Laravel Docker containers
#    - Instance templates and groups
#    - Auto-scaling configuration
# ==========================================================================

# --------------------------------------------------------------------------
#  Service Account for Compute Instances
# --------------------------------------------------------------------------
resource "google_service_account" "laravel_compute_sa" {
  account_id   = "laravel-compute-${var.environment[local.env]}"
  display_name = "Laravel Compute Service Account"
  description  = "Service account for Laravel Compute Engine instances"
}

resource "google_service_account_key" "laravel_compute_sa_key" {
  service_account_id = google_service_account.laravel_compute_sa.name
}

# --------------------------------------------------------------------------
#  IAM Bindings for Service Account
# --------------------------------------------------------------------------
resource "google_project_iam_member" "laravel_compute_sa_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.laravel_compute_sa.email}"
}

resource "google_project_iam_member" "laravel_compute_sa_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.laravel_compute_sa.email}"
}

# --------------------------------------------------------------------------
#  Startup Script for Docker Installation
# --------------------------------------------------------------------------
locals {
  startup_script = templatefile("${path.module}/scripts/startup.sh", {
    docker_image          = var.docker_image
    github_username       = var.github_username
    github_token          = var.github_token
    frankenphp_port       = var.frankenphp_port
    app_key              = var.app_key
    app_env              = var.app_env
    app_debug            = var.app_debug
    db_host              = var.db_host
    db_port              = var.db_port
    db_name              = var.db_name
    db_user              = var.db_user
    db_password          = var.db_password
    environment          = var.environment[local.env]
    base_domain          = var.base_domain
    app_subdomain        = var.app_subdomain
    tenant_routing_enabled = var.tenant_routing_enabled
  })
}

# --------------------------------------------------------------------------
#  Instance Template
# --------------------------------------------------------------------------
resource "google_compute_instance_template" "laravel_template" {
  name_prefix  = "laravel-template-${var.environment[local.env]}-"
  description  = "Template for Laravel Docker instances"
  machine_type = var.machine_type

  labels = local.labels

  # Boot disk
  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2204-lts"
    auto_delete  = true
    boot         = true
    disk_size_gb = var.disk_size
    disk_type    = var.disk_type
  }

  # Network interface
  network_interface {
    network    = local.vpc_name
    subnetwork = local.public_subnet_names[0]
    
    # External IP for internet access
    access_config {
      nat_ip = null
    }
  }

  # Service account
  service_account {
    email  = google_service_account.laravel_compute_sa.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write"
    ]
  }

  # Metadata and startup script
  metadata = {
    startup-script = local.startup_script
    ssh-keys       = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  # Network tags for firewall rules
  tags = ["laravel-web", "laravel-app", "laravel-ssh"]

  # Preemptible configuration
  scheduling {
    preemptible       = var.preemptible
    automatic_restart = !var.preemptible
  }

  # Create new instances before destroying old ones
  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    google_service_account.laravel_compute_sa,
    google_project_iam_member.laravel_compute_sa_logging,
    google_project_iam_member.laravel_compute_sa_monitoring
  ]
}

# --------------------------------------------------------------------------
#  Managed Instance Group
# --------------------------------------------------------------------------
resource "google_compute_instance_group_manager" "laravel_group" {
  name               = "laravel-group-${var.environment[local.env]}"
  base_instance_name = "laravel-instance"
  zone               = var.gcp_zone
  target_size        = var.instance_count

  version {
    instance_template = google_compute_instance_template.laravel_template.id
  }

  # Health check for auto-healing
  auto_healing_policies {
    health_check      = google_compute_health_check.laravel_health_check.id
    initial_delay_sec = 300
  }

  # Update policy
  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 1
    max_unavailable_fixed = 0
  }

  depends_on = [google_compute_instance_template.laravel_template]
}

# --------------------------------------------------------------------------
#  Health Check
# --------------------------------------------------------------------------
resource "google_compute_health_check" "laravel_health_check" {
  name               = "laravel-health-check-${var.environment[local.env]}"
  check_interval_sec = 10
  timeout_sec        = 5
  healthy_threshold  = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = "80"
    request_path = "/"
  }

  log_config {
    enable = true
  }
}

# --------------------------------------------------------------------------
#  Autoscaler
# --------------------------------------------------------------------------
resource "google_compute_autoscaler" "laravel_autoscaler" {
  name   = "laravel-autoscaler-${var.environment[local.env]}"
  zone   = var.gcp_zone
  target = google_compute_instance_group_manager.laravel_group.id

  autoscaling_policy {
    max_replicas    = var.environment[local.env] == "prod" ? 10 : 5
    min_replicas    = var.environment[local.env] == "prod" ? 2 : 1
    cooldown_period = 60

    cpu_utilization {
      target = 0.7
    }

    load_balancing_utilization {
      target = 0.8
    }
  }

  depends_on = [google_compute_instance_group_manager.laravel_group]
}
