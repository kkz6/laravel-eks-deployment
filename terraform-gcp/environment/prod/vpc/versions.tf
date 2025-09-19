# ==========================================================================
#  Terraform and Provider Versions
# ==========================================================================

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  
  backend "gcs" {
    bucket = "laravel-terraform-state-bucket"
    prefix = "vpc"
  }
}
