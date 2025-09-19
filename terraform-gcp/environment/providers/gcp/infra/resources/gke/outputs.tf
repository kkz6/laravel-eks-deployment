# ==========================================================================
#  GKE: outputs.tf (Output Terraform)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Return value terraform output
# ==========================================================================

# --------------------------------------------------------------------------
#  GKE Cluster Outputs
# --------------------------------------------------------------------------
output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.laravel_cluster.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.laravel_cluster.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = google_container_cluster.laravel_cluster.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "GKE cluster location"
  value       = google_container_cluster.laravel_cluster.location
}

# --------------------------------------------------------------------------
#  Redis VM Outputs
# --------------------------------------------------------------------------
output "redis_vm_name" {
  description = "Redis VM instance name"
  value       = google_compute_instance.redis_vm.name
}

output "redis_internal_ip" {
  description = "Redis VM internal IP address"
  value       = google_compute_instance.redis_vm.network_interface[0].network_ip
}

output "redis_external_ip" {
  description = "Redis VM external IP address (for setup only)"
  value       = google_compute_instance.redis_vm.network_interface[0].access_config[0].nat_ip
}

output "redis_connection_string" {
  description = "Redis connection string for Kubernetes"
  value       = "${google_compute_instance.redis_vm.network_interface[0].network_ip}:6379"
}

# --------------------------------------------------------------------------
#  Kubernetes Configuration
# --------------------------------------------------------------------------
output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.laravel_cluster.name} --region=${var.gcp_region} --project=${var.project_id}"
}

output "kubernetes_namespace" {
  description = "Kubernetes namespace for Laravel application"
  value       = "laravel-app"
}

# --------------------------------------------------------------------------
#  Service Account Outputs
# --------------------------------------------------------------------------
output "gke_service_account_email" {
  description = "GKE nodes service account email"
  value       = google_service_account.gke_nodes_sa.email
}

output "redis_service_account_email" {
  description = "Redis VM service account email"
  value       = google_service_account.redis_vm_sa.email
}

# --------------------------------------------------------------------------
#  Deployment Information
# --------------------------------------------------------------------------
output "deployment_architecture" {
  description = "Summary of hybrid deployment architecture"
  value = {
    database    = "Cloud SQL (managed)"
    redis       = "VM-based (cost-effective)"
    kubernetes  = "GKE (container orchestration)"
    containers = {
      http      = "Auto-scaling pods"
      scheduler = "Single pod (no scaling)"
      horizon   = "Auto-scaling workers"
    }
  }
}

output "next_steps" {
  description = "Next steps after infrastructure deployment"
  value = {
    step_1 = "Configure kubectl: ${local.kubectl_config_command}"
    step_2 = "Update secrets in k8s-manifests/secrets.yaml"
    step_3 = "Deploy manifests: kubectl apply -f k8s-manifests/"
    step_4 = "Check pods: kubectl get pods -n laravel-app"
    step_5 = "Get ingress IP: kubectl get ingress -n laravel-app"
  }
}

# --------------------------------------------------------------------------
#  Local values for output
# --------------------------------------------------------------------------
locals {
  kubectl_config_command = "gcloud container clusters get-credentials ${google_container_cluster.laravel_cluster.name} --region=${var.gcp_region} --project=${var.project_id}"
}
