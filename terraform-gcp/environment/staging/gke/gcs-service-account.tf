# ==========================================================================
#  GCS Service Account for Laravel Application
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Service account for GCS access
#    - IAM permissions for storage operations
#    - Workload Identity binding
# ==========================================================================

# --------------------------------------------------------------------------
#  Service Account for GCS Access
# --------------------------------------------------------------------------
resource "google_service_account" "laravel_gcs_sa" {
  account_id   = "laravel-gcs-${var.environment[local.env]}"
  display_name = "Laravel GCS Service Account"
  description  = "Service account for Laravel application to access Google Cloud Storage"
}

# --------------------------------------------------------------------------
#  IAM Permissions for GCS Multi-Tenant Setup
# --------------------------------------------------------------------------
# Storage Admin role allows creating/deleting buckets and managing all objects
resource "google_project_iam_member" "laravel_gcs_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.laravel_gcs_sa.email}"
}

# Additional permissions for multi-tenant bucket management
# Note: roles/storage.admin already includes bucket creation permissions
# resource "google_project_iam_member" "laravel_gcs_bucket_creator" {
#   project = var.project_id
#   role    = "roles/storage.buckets.create"
#   member  = "serviceAccount:${google_service_account.laravel_gcs_sa.email}"
# }

# Service Usage Consumer to use GCS APIs
resource "google_project_iam_member" "laravel_service_usage_consumer" {
  project = var.project_id
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "serviceAccount:${google_service_account.laravel_gcs_sa.email}"
}

# --------------------------------------------------------------------------
#  Workload Identity Binding
# --------------------------------------------------------------------------
resource "google_service_account_iam_member" "laravel_workload_identity" {
  service_account_id = google_service_account.laravel_gcs_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.laravel_namespace}/${var.laravel_service_account_name}]"
}

# --------------------------------------------------------------------------
#  Service Account Token Creator (for bucket creation)
# --------------------------------------------------------------------------
resource "google_project_iam_member" "laravel_token_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.laravel_gcs_sa.email}"
}

# --------------------------------------------------------------------------
#  Default GCS Bucket (Optional - for shared resources)
# --------------------------------------------------------------------------
# This bucket can be used for shared resources like app assets, logs, etc.
# Tenant-specific buckets will be created dynamically by the Laravel application
resource "google_storage_bucket" "laravel_shared_storage" {
  name          = "${var.project_id}-laravel-shared-${var.environment[local.env]}"
  location      = var.gcs_bucket_location
  storage_class = var.gcs_storage_class
  
  # Enable versioning
  versioning {
    enabled = true
  }
  
  # Enable uniform bucket-level access (required by organization policy)
  uniform_bucket_level_access = true
  
  # Lifecycle management
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
  
  # CORS settings for web access
  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
  
  # Labels
  labels = local.labels
}

# --------------------------------------------------------------------------
#  Bucket Naming Convention for Multi-Tenant Setup
# --------------------------------------------------------------------------
# The Laravel application will create buckets with this pattern:
# ${var.project_id}-tenant-{tenant-id}-${var.environment[local.env]}
# Example: myproject-tenant-acme-corp-staging

# --------------------------------------------------------------------------
#  Outputs
# --------------------------------------------------------------------------
output "gcs_service_account_email" {
  description = "Email of the GCS service account"
  value       = google_service_account.laravel_gcs_sa.email
}

output "gcs_shared_bucket_name" {
  description = "Name of the shared GCS bucket"
  value       = google_storage_bucket.laravel_shared_storage.name
}

output "gcs_shared_bucket_url" {
  description = "URL of the shared GCS bucket"
  value       = google_storage_bucket.laravel_shared_storage.url
}

output "tenant_bucket_prefix" {
  description = "Prefix for tenant-specific buckets"
  value       = "${var.project_id}-tenant"
}
