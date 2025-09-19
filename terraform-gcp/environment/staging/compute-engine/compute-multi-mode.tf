# ==========================================================================
#  Compute Engine: compute-multi-mode.tf (Multi-Mode Container Setup)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Separate instance groups for HTTP, Scheduler, and Horizon
#    - Different scaling policies for each mode
#    - Redis integration for queue management
# ==========================================================================

# --------------------------------------------------------------------------
#  Startup Scripts for Different Modes
# --------------------------------------------------------------------------
locals {
  # Common variables for all container modes
  common_template_vars = {
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
    redis_host           = google_redis_instance.laravel_redis.host
    redis_port           = google_redis_instance.laravel_redis.port
    redis_auth           = var.redis_auth_enabled ? random_password.redis_auth[0].result : ""
  }

  # HTTP Frontend containers
  http_startup_script = templatefile("${path.module}/scripts/startup-http.sh", merge(local.common_template_vars, {
    container_mode = "http"
  }))

  # Scheduler containers (Laravel cron jobs)
  scheduler_startup_script = templatefile("${path.module}/scripts/startup-scheduler.sh", merge(local.common_template_vars, {
    container_mode = "scheduler"
  }))

  # Horizon containers (Laravel queue workers)
  horizon_startup_script = templatefile("${path.module}/scripts/startup-horizon.sh", merge(local.common_template_vars, {
    container_mode = "horizon"
  }))
}

# --------------------------------------------------------------------------
#  HTTP Frontend Instance Template
# --------------------------------------------------------------------------
resource "google_compute_instance_template" "laravel_http_template" {
  name_prefix  = "laravel-http-template-${var.environment[local.env]}-"
  description  = "Template for Laravel HTTP frontend instances"
  machine_type = var.machine_type

  labels = merge(local.labels, {
    container_mode = "http"
  })

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2204-lts"
    auto_delete  = true
    boot         = true
    disk_size_gb = var.disk_size
    disk_type    = var.disk_type
  }

  network_interface {
    network    = var.use_remote_state ? local.vpc_name : "default"
    subnetwork = var.use_remote_state && length(local.public_subnet_names) > 0 ? local.public_subnet_names[0] : null
    
    access_config {
      nat_ip = null
    }
  }

  service_account {
    email  = google_service_account.laravel_compute_sa.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write"
    ]
  }

  metadata = merge({
    startup-script = local.http_startup_script
  }, var.ssh_public_key != "" ? {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
  } : {})

  tags = ["laravel-web", "laravel-app", "laravel-ssh", "laravel-http"]

  scheduling {
    preemptible       = var.preemptible
    automatic_restart = !var.preemptible
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    google_service_account.laravel_compute_sa,
    google_redis_instance.laravel_redis
  ]
}

# --------------------------------------------------------------------------
#  Scheduler Instance Template (Single instance, no scaling)
# --------------------------------------------------------------------------
resource "google_compute_instance_template" "laravel_scheduler_template" {
  name_prefix  = "laravel-scheduler-template-${var.environment[local.env]}-"
  description  = "Template for Laravel scheduler instance"
  machine_type = var.environment[local.env] == "prod" ? "e2-small" : "e2-micro"

  labels = merge(local.labels, {
    container_mode = "scheduler"
  })

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2204-lts"
    auto_delete  = true
    boot         = true
    disk_size_gb = 10  # Smaller disk for scheduler
    disk_type    = var.disk_type
  }

  network_interface {
    network    = var.use_remote_state ? local.vpc_name : "default"
    subnetwork = var.use_remote_state && length(local.private_subnet_names) > 0 ? local.private_subnet_names[0] : null
    
    # No external IP needed for scheduler
    access_config {
      nat_ip = null
    }
  }

  service_account {
    email  = google_service_account.laravel_compute_sa.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write"
    ]
  }

  metadata = merge({
    startup-script = local.scheduler_startup_script
  }, var.ssh_public_key != "" ? {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
  } : {})

  tags = ["laravel-scheduler", "laravel-ssh"]

  scheduling {
    preemptible       = false  # Scheduler should not be preemptible
    automatic_restart = true
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    google_service_account.laravel_compute_sa,
    google_redis_instance.laravel_redis
  ]
}

# --------------------------------------------------------------------------
#  Horizon Worker Instance Template
# --------------------------------------------------------------------------
resource "google_compute_instance_template" "laravel_horizon_template" {
  name_prefix  = "laravel-horizon-template-${var.environment[local.env]}-"
  description  = "Template for Laravel Horizon worker instances"
  machine_type = var.environment[local.env] == "prod" ? var.machine_type : "e2-small"

  labels = merge(local.labels, {
    container_mode = "horizon"
  })

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2204-lts"
    auto_delete  = true
    boot         = true
    disk_size_gb = var.disk_size
    disk_type    = var.disk_type
  }

  network_interface {
    network    = var.use_remote_state ? local.vpc_name : "default"
    subnetwork = var.use_remote_state && length(local.private_subnet_names) > 0 ? local.private_subnet_names[0] : null
    
    # External IP for pulling Docker images
    access_config {
      nat_ip = null
    }
  }

  service_account {
    email  = google_service_account.laravel_compute_sa.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write"
    ]
  }

  metadata = merge({
    startup-script = local.horizon_startup_script
  }, var.ssh_public_key != "" ? {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
  } : {})

  tags = ["laravel-horizon", "laravel-ssh"]

  scheduling {
    preemptible       = var.environment[local.env] == "prod" ? false : var.preemptible
    automatic_restart = !var.preemptible
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    google_service_account.laravel_compute_sa,
    google_redis_instance.laravel_redis
  ]
}

# --------------------------------------------------------------------------
#  HTTP Frontend Instance Group Manager
# --------------------------------------------------------------------------
resource "google_compute_instance_group_manager" "laravel_http_group" {
  name               = "laravel-http-group-${var.environment[local.env]}"
  base_instance_name = "laravel-http"
  zone               = var.gcp_zone
  target_size        = var.http_instance_count

  version {
    instance_template = google_compute_instance_template.laravel_http_template.id
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.laravel_health_check.id
    initial_delay_sec = 300
  }

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 1
    max_unavailable_fixed = 0
  }

  depends_on = [google_compute_instance_template.laravel_http_template]
}

# --------------------------------------------------------------------------
#  Scheduler Instance Group Manager (Single instance, no auto-scaling)
# --------------------------------------------------------------------------
resource "google_compute_instance_group_manager" "laravel_scheduler_group" {
  name               = "laravel-scheduler-group-${var.environment[local.env]}"
  base_instance_name = "laravel-scheduler"
  zone               = var.gcp_zone
  target_size        = var.scheduler_instance_count

  version {
    instance_template = google_compute_instance_template.laravel_scheduler_template.id
  }

  # No auto-healing for scheduler (to prevent duplicate cron jobs)
  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 0
    max_unavailable_fixed = 1
  }

  depends_on = [google_compute_instance_template.laravel_scheduler_template]
}

# --------------------------------------------------------------------------
#  Horizon Worker Instance Group Manager
# --------------------------------------------------------------------------
resource "google_compute_instance_group_manager" "laravel_horizon_group" {
  name               = "laravel-horizon-group-${var.environment[local.env]}"
  base_instance_name = "laravel-horizon"
  zone               = var.gcp_zone
  target_size        = var.horizon_instance_count

  version {
    instance_template = google_compute_instance_template.laravel_horizon_template.id
  }

  # Auto-healing for horizon workers
  auto_healing_policies {
    health_check      = google_compute_health_check.laravel_horizon_health_check.id
    initial_delay_sec = 300
  }

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 1
    max_unavailable_fixed = 0
  }

  depends_on = [google_compute_instance_template.laravel_horizon_template]
}

# --------------------------------------------------------------------------
#  Health Check for Horizon Workers
# --------------------------------------------------------------------------
resource "google_compute_health_check" "laravel_horizon_health_check" {
  name               = "laravel-horizon-health-check-${var.environment[local.env]}"
  check_interval_sec = 30
  timeout_sec        = 10
  healthy_threshold  = 2
  unhealthy_threshold = 3

  # Health check via command (since Horizon doesn't serve HTTP)
  tcp_health_check {
    port = "22"  # Just check if instance is responsive
  }

  log_config {
    enable = true
  }
}

# --------------------------------------------------------------------------
#  HTTP Autoscaler (Only for HTTP frontend)
# --------------------------------------------------------------------------
resource "google_compute_autoscaler" "laravel_http_autoscaler" {
  name   = "laravel-http-autoscaler-${var.environment[local.env]}"
  zone   = var.gcp_zone
  target = google_compute_instance_group_manager.laravel_http_group.id

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

  depends_on = [google_compute_instance_group_manager.laravel_http_group]
}

# --------------------------------------------------------------------------
#  Horizon Autoscaler (Scale based on queue size)
# --------------------------------------------------------------------------
resource "google_compute_autoscaler" "laravel_horizon_autoscaler" {
  name   = "laravel-horizon-autoscaler-${var.environment[local.env]}"
  zone   = var.gcp_zone
  target = google_compute_instance_group_manager.laravel_horizon_group.id

  autoscaling_policy {
    max_replicas    = var.environment[local.env] == "prod" ? 5 : 3
    min_replicas    = 1
    cooldown_period = 120  # Longer cooldown for queue processing

    cpu_utilization {
      target = 0.8  # Higher CPU target for workers
    }

    # Custom metrics for queue size could be added here
  }

  depends_on = [google_compute_instance_group_manager.laravel_horizon_group]
}
