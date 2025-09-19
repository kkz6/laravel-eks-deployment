# ==========================================================================
#  Core: outputs.tf (Output Terraform)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Return value terraform output
# ==========================================================================

# --------------------------------------------------------------------------
#  VPC Outputs
# --------------------------------------------------------------------------
output "vpc_id" {
  description = "ID of the VPC"
  value       = google_compute_network.laravel_vpc.id
}

output "vpc_name" {
  description = "Name of the VPC"
  value       = google_compute_network.laravel_vpc.name
}

output "vpc_self_link" {
  description = "Self link of the VPC"
  value       = google_compute_network.laravel_vpc.self_link
}

# --------------------------------------------------------------------------
#  Subnet Outputs
# --------------------------------------------------------------------------
output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = google_compute_subnetwork.public_subnets[*].id
}

output "public_subnet_names" {
  description = "Names of the public subnets"
  value       = google_compute_subnetwork.public_subnets[*].name
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = google_compute_subnetwork.private_subnets[*].id
}

output "private_subnet_names" {
  description = "Names of the private subnets"
  value       = google_compute_subnetwork.private_subnets[*].name
}

# --------------------------------------------------------------------------
#  Router & NAT Outputs
# --------------------------------------------------------------------------
output "router_name" {
  description = "Name of the Cloud Router"
  value       = google_compute_router.laravel_router.name
}

output "nat_name" {
  description = "Name of the Cloud NAT"
  value       = google_compute_router_nat.laravel_nat.name
}

# --------------------------------------------------------------------------
#  Environment Outputs
# --------------------------------------------------------------------------
output "environment" {
  description = "Environment name"
  value       = var.environment[local.env]
}

output "region" {
  description = "GCP region"
  value       = var.gcp_region
}

output "zone" {
  description = "GCP zone"
  value       = var.gcp_zone
}
