# ==========================================================================
#  GKE: gke-cluster.tf (Google Kubernetes Engine Cluster)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - GKE cluster for Laravel containers
#    - Node pools with auto-scaling
#    - Network and security configuration
# ==========================================================================

# --------------------------------------------------------------------------
#  GKE Cluster
# --------------------------------------------------------------------------
resource "google_container_cluster" "laravel_cluster" {
  name     = "${var.cluster_name}-${var.environment[local.env]}"
  location = var.gcp_region

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Kubernetes version
  min_master_version = var.kubernetes_version

  # Network configuration
  network    = "default"  # Using default VPC for simplicity
  subnetwork = null

  # IP allocation for pods and services
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "10.1.0.0/16"
    services_ipv4_cidr_block = "10.2.0.0/16"
  }

  # Master auth configuration
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # Workload Identity for secure pod-to-GCP communication
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Network policy
  network_policy {
    enabled = true
  }

  # Addons
  addons_config {
    http_load_balancing {
      disabled = false
    }
    
    horizontal_pod_autoscaling {
      disabled = false
    }
    
    network_policy_config {
      disabled = false
    }
    
    gcp_filestore_csi_driver_config {
      enabled = false
    }
    
    gcs_fuse_csi_driver_config {
      enabled = false
    }
  }

  # Maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  # Logging and monitoring
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Resource labels
  resource_labels = local.labels

  # Lifecycle management
  lifecycle {
    ignore_changes = [
      initial_node_count,
    ]
  }
}

# --------------------------------------------------------------------------
#  Primary Node Pool
# --------------------------------------------------------------------------
resource "google_container_node_pool" "laravel_nodes" {
  name       = "laravel-nodes-${var.environment[local.env]}"
  location   = var.gcp_region
  cluster    = google_container_cluster.laravel_cluster.name
  
  # Node count and autoscaling
  initial_node_count = var.node_count
  
  dynamic "autoscaling" {
    for_each = var.enable_autoscaling ? [1] : []
    content {
      min_node_count = var.min_node_count
      max_node_count = var.max_node_count
    }
  }

  # Node configuration
  node_config {
    preemptible  = var.environment[local.env] == "prod" ? false : true
    machine_type = var.node_machine_type
    disk_size_gb = var.node_disk_size
    disk_type    = var.node_disk_type

    # Service account for nodes
    service_account = google_service_account.gke_nodes_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Labels for nodes
    labels = merge(local.labels, {
      node_pool = "primary"
    })

    # Tags for firewall rules
    tags = ["laravel-gke-node"]

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Shielded instance configuration
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  # Upgrade settings
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  # Management settings
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  depends_on = [
    google_container_cluster.laravel_cluster,
    google_service_account.gke_nodes_sa
  ]
}

# --------------------------------------------------------------------------
#  Service Account for GKE Nodes
# --------------------------------------------------------------------------
resource "google_service_account" "gke_nodes_sa" {
  account_id   = "gke-nodes-${var.environment[local.env]}"
  display_name = "GKE Nodes Service Account"
  description  = "Service account for GKE nodes"
}

# IAM bindings for GKE nodes
resource "google_project_iam_member" "gke_nodes_registry" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.gke_nodes_sa.email}"
}

resource "google_project_iam_member" "gke_nodes_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes_sa.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes_sa.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_nodes_sa.email}"
}
