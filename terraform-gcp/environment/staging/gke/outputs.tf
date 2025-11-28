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

# --------------------------------------------------------------------------
#  Deployment Information
# --------------------------------------------------------------------------
output "deployment_architecture" {
  description = "Summary of deployment architecture"
  value = {
    database   = "Cloud SQL (managed)"
    redis      = "Kubernetes pod (in-cluster)"
    kubernetes = "GKE (container orchestration with private nodes)"
    containers = {
      http      = "Auto-scaling pods"
      scheduler = "Single pod (no scaling)"
      horizon   = "Auto-scaling workers"
    }
    networking = {
      node_type   = "Private nodes (no external IPs)"
      outbound_ip = "Cloud NAT (single static IP)"
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
      http       = kubernetes_deployment.laravel_http.metadata[0].name
      scheduler  = kubernetes_deployment.laravel_scheduler.metadata[0].name
      horizon    = kubernetes_deployment.laravel_horizon.metadata[0].name
      nxtract    = kubernetes_deployment.nxtract_api.metadata[0].name
    }
    services = {
      http    = kubernetes_service.laravel_http_service.metadata[0].name
      nxtract = kubernetes_service.nxtract_api_service.metadata[0].name
    }
    ingress = kubernetes_ingress_v1.laravel_ingress.metadata[0].name
  }
}

# --------------------------------------------------------------------------
#  Nxtract API Outputs
# --------------------------------------------------------------------------
output "nxtract_api_internal_url" {
  description = "Internal Kubernetes URL for Nxtract API (use this in Laravel app)"
  value       = "http://nxtract-api-service.nxtract-api.svc.cluster.local"
}

output "nxtract_api_namespace" {
  description = "Kubernetes namespace for Nxtract API"
  value       = kubernetes_namespace.nxtract_api.metadata[0].name
}

output "next_steps" {
  description = "Next steps after infrastructure deployment"
  value = {
    step_1 = "Configure kubectl: ${local.kubectl_config_command}"
    step_2 = "Check pods: kubectl get pods -n laravel-app"
    step_3 = "Configure Cloudflare DNS with IP: ${google_compute_global_address.laravel_ingress_ip.address}"
    step_4 = "Test application: https://${var.app_subdomain}.${var.base_domain}"
    step_5 = "Verify NAT IP for outbound requests: ${google_compute_address.nat_ip.address}"
  }
}

# --------------------------------------------------------------------------
#  Cloud NAT Outputs
# --------------------------------------------------------------------------
output "nat_external_ip" {
  description = "Static external IP address used by Cloud NAT for outbound connections"
  value       = google_compute_address.nat_ip.address
}

output "nat_router_name" {
  description = "Cloud Router name for NAT gateway"
  value       = google_compute_router.nat_router.name
}

output "nat_gateway_name" {
  description = "Cloud NAT gateway name"
  value       = google_compute_router_nat.nat_gateway.name
}

# --------------------------------------------------------------------------
#  Local values for output
# --------------------------------------------------------------------------
locals {
  kubectl_config_command = "gcloud container clusters get-credentials ${google_container_cluster.laravel_cluster.name} --region=${var.gcp_region} --project=${var.project_id}"
}
