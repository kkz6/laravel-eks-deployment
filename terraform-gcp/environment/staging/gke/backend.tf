# ==========================================================================
#  GKE: backend.tf (Backend Terraform)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Backend state configuration
#    - Using Google Cloud Storage
# ==========================================================================

terraform {
  backend "gcs" {
    bucket = "laravel-gcp-terraform-state-stg" # This should match your environment
    prefix = "gke/terraform.tfstate"
  }
}
