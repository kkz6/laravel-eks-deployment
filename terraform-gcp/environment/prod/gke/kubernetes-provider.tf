# ==========================================================================
#  GKE: kubernetes-provider.tf (Kubernetes Provider Configuration)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Kubernetes provider configuration
#    - Connects to GKE cluster after creation
# ==========================================================================

# --------------------------------------------------------------------------
#  Get GKE cluster authentication info
# --------------------------------------------------------------------------
data "google_client_config" "default" {}

data "google_container_cluster" "gke_cluster" {
  name     = google_container_cluster.laravel_cluster.name
  location = google_container_cluster.laravel_cluster.location

  depends_on = [
    google_container_cluster.laravel_cluster,
    google_container_node_pool.laravel_nodes
  ]
}

# --------------------------------------------------------------------------
#  Kubernetes Provider Configuration
# --------------------------------------------------------------------------
provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.gke_cluster.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.gke_cluster.master_auth[0].cluster_ca_certificate)
  
  # Ignore annotations for managed resources
  ignore_annotations = [
    "kubectl.kubernetes.io/last-applied-configuration"
  ]
}
