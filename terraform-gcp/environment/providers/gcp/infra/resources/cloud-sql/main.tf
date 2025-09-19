# ==========================================================================
#  Cloud SQL: main.tf (Main Terraform)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Workspace Environment
#    - GCP Provider
#    - Common Labels
# ==========================================================================

# --------------------------------------------------------------------------
#  Workspace Environment
# --------------------------------------------------------------------------
locals {
  env = terraform.workspace
}

# --------------------------------------------------------------------------
#  Provider Module Terraform
# --------------------------------------------------------------------------
provider "google" {
  project = var.project_id
  region  = var.gcp_region
  
  # Use Application Default Credentials (ADC)
  # Run: gcloud auth application-default login
}

# --------------------------------------------------------------------------
#  Start HERE
# --------------------------------------------------------------------------
locals {
  labels = {
    environment      = var.environment[local.env]
    department       = var.department
    department_group = "${var.environment[local.env]}-${var.department}"
    terraform        = "true"
    project         = "laravel-gcp-deployment"
    component       = "cloud-sql"
  }
}
