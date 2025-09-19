# ==========================================================================
#  VPC Outputs
# ==========================================================================

output "vpc_id" {
  description = "The ID of the VPC"
  value       = google_compute_network.laravel_vpc.id
}

output "vpc_name" {
  description = "The name of the VPC"
  value       = google_compute_network.laravel_vpc.name
}

output "public_subnet_id" {
  description = "The ID of the public subnet"
  value       = google_compute_subnetwork.public_subnet.id
}

output "public_subnet_name" {
  description = "The name of the public subnet"
  value       = google_compute_subnetwork.public_subnet.name
}

output "private_subnet_id" {
  description = "The ID of the private subnet"
  value       = google_compute_subnetwork.private_subnet.id
}

output "private_subnet_name" {
  description = "The name of the private subnet"
  value       = google_compute_subnetwork.private_subnet.name
}

output "gke_pod_secondary_range_name" {
  description = "The name of the GKE pod secondary range"
  value       = "gke-pods-${local.env}"
}

output "gke_service_secondary_range_name" {
  description = "The name of the GKE service secondary range"
  value       = "gke-services-${local.env}"
}

output "router_name" {
  description = "The name of the Cloud Router"
  value       = google_compute_router.laravel_router.name
}

output "nat_name" {
  description = "The name of the NAT Gateway"
  value       = google_compute_router_nat.laravel_nat.name
}
