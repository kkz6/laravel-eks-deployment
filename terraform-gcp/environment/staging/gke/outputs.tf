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

output "redis_password" {
  description = "Redis authentication password"
  value       = var.redis_password != "" ? var.redis_password : random_password.redis_password[0].result
  sensitive   = true
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
    database   = "Cloud SQL (managed)"
    redis      = "VM-based (cost-effective)"
    kubernetes = "GKE (container orchestration)"
    containers = {
      http      = "Auto-scaling pods"
      scheduler = "Single pod (no scaling)"
      horizon   = "Auto-scaling workers"
    }
  }
}

output "ingress_ip" {
  description = "Static IP address for the Kubernetes ingress"
  value       = google_compute_global_address.laravel_ingress_ip.address
}

output "application_urls" {
  description = "URLs for the multi-tenant Laravel application"
  value = {
    main_app       = var.base_domain != "" ? "https://${var.app_subdomain}.${var.base_domain}" : "http://${google_compute_global_address.laravel_ingress_ip.address}"
    tenant_example = var.base_domain != "" ? "https://tenant1.${var.app_subdomain}.${var.base_domain}" : null
  }
}

output "kubernetes_resources" {
  description = "Deployed Kubernetes resources"
  value = {
    namespace = kubernetes_namespace.laravel_app.metadata[0].name
    deployments = {
      http      = kubernetes_deployment.laravel_http.metadata[0].name
      scheduler = kubernetes_deployment.laravel_scheduler.metadata[0].name
      horizon   = kubernetes_deployment.laravel_horizon.metadata[0].name
    }
    service = kubernetes_service.laravel_http_service.metadata[0].name
    ingress = kubernetes_ingress_v1.laravel_ingress.metadata[0].name
  }
}

output "next_steps" {
  description = "Next steps after infrastructure deployment"
  value = {
    step_1 = "Configure kubectl: ${local.kubectl_config_command}"
    step_2 = "Check pods: kubectl get pods -n laravel-app"
    step_3 = "Configure Cloudflare DNS with IP: ${google_compute_global_address.laravel_ingress_ip.address}"
    step_4 = "Test application: https://${var.app_subdomain}.${var.base_domain}"
  }
}

# --------------------------------------------------------------------------
#  Local values for output
# --------------------------------------------------------------------------
locals {
  kubectl_config_command = "gcloud container clusters get-credentials ${google_container_cluster.laravel_cluster.name} --region=${var.gcp_region} --project=${var.project_id}"
}
