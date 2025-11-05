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
    bucket = "zyoshu-terraform-state-staging" # Bucket name with env
    prefix = "gke/terraform.tfstate"
  }
}
