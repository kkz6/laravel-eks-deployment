# ==========================================================================
#  Cloud SQL: outputs.tf (Output Terraform)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Return value terraform output
# ==========================================================================

# --------------------------------------------------------------------------
#  Database Instance Outputs
# --------------------------------------------------------------------------
output "database_instance_name" {
  description = "Name of the Cloud SQL instance"
  value       = google_sql_database_instance.laravel_db_instance.name
}

output "database_connection_name" {
  description = "Connection name of the Cloud SQL instance"
  value       = google_sql_database_instance.laravel_db_instance.connection_name
}

output "database_public_ip" {
  description = "Public IP address of the Cloud SQL instance (disabled for VPC-only)"
  value       = null
}

output "database_private_ip" {
  description = "Private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.laravel_db_instance.private_ip_address
}

output "database_self_link" {
  description = "Self link of the Cloud SQL instance"
  value       = google_sql_database_instance.laravel_db_instance.self_link
}

# --------------------------------------------------------------------------
#  Database Configuration Outputs
# --------------------------------------------------------------------------
output "database_name" {
  description = "Name of the created database"
  value       = google_sql_database.laravel_database.name
}

output "database_user" {
  description = "Database user name"
  value       = google_sql_user.laravel_user.name
}

output "database_password" {
  description = "Database user password"
  value       = local.database_password
  sensitive   = true
}

output "root_password" {
  description = "Root user password"
  value       = local.root_password
  sensitive   = true
}

# --------------------------------------------------------------------------
#  Connection Information
# --------------------------------------------------------------------------
output "database_host" {
  description = "Database host (private IP for VPC access)"
  value       = google_sql_database_instance.laravel_db_instance.private_ip_address
}

output "database_port" {
  description = "Database port"
  value       = "3306"
}

output "database_url" {
  description = "Complete database connection URL (private IP)"
  value       = "mysql://${google_sql_user.laravel_user.name}:${local.database_password}@${google_sql_database_instance.laravel_db_instance.private_ip_address}:3306/${google_sql_database.laravel_database.name}"
  sensitive   = true
}

# --------------------------------------------------------------------------
#  SSL Certificate Outputs
# --------------------------------------------------------------------------
output "ssl_certificate" {
  description = "SSL certificate for secure connections"
  value       = var.require_ssl ? google_sql_ssl_cert.laravel_ssl_cert[0].cert : null
  sensitive   = true
}

output "ssl_private_key" {
  description = "SSL private key for secure connections"
  value       = var.require_ssl ? google_sql_ssl_cert.laravel_ssl_cert[0].private_key : null
  sensitive   = true
}

output "ssl_server_ca_cert" {
  description = "SSL server CA certificate"
  value       = var.require_ssl ? google_sql_ssl_cert.laravel_ssl_cert[0].server_ca_cert : null
  sensitive   = true
}

# --------------------------------------------------------------------------
#  Replica Outputs (if enabled)
# --------------------------------------------------------------------------
output "replica_instance_name" {
  description = "Name of the replica instance (if enabled)"
  value       = var.enable_replica ? google_sql_database_instance.laravel_db_replica[0].name : null
}

output "replica_public_ip" {
  description = "Public IP of the replica instance (if enabled)"
  value       = var.enable_replica ? google_sql_database_instance.laravel_db_replica[0].public_ip_address : null
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

# --------------------------------------------------------------------------
#  Laravel Environment Variables
# --------------------------------------------------------------------------
output "laravel_env_vars" {
  description = "Environment variables for Laravel application"
  value = {
    DB_CONNECTION = "mysql"
    DB_HOST      = google_sql_database_instance.laravel_db_instance.private_ip_address
    DB_PORT      = "3306"
    DB_DATABASE  = google_sql_database.laravel_database.name
    DB_USERNAME  = google_sql_user.laravel_user.name
    DB_PASSWORD  = local.database_password
  }
  sensitive = true
}
