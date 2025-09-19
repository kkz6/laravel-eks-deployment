# ==========================================================================
#  TFState: variables.tf (Global Environment)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Input Variable for Environment Variables
# ==========================================================================

# ------------------------------------
#  GCP Project & Region
# ------------------------------------
variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "gcp_region" {
  type        = string
  description = "GCP Region Target Deployment"
  default     = "us-central1"
}

variable "gcp_zone" {
  type        = string
  description = "GCP Zone Target Deployment"
  default     = "us-central1-a"
}

# ------------------------------------
#  Workspace
# ------------------------------------
variable "env" {
  type        = map(string)
  description = "Workspace Environment Selection"
  default = {
    lab     = "lab"
    staging = "staging"
    prod    = "prod"
  }
}

# ------------------------------------
#  Environment Resources Labels
# ------------------------------------
variable "environment" {
  type        = map(string)
  description = "Target Environment (labels)"
  default = {
    lab     = "rnd"
    staging = "stg"
    prod    = "prod"
  }
}

# ------------------------------------
#  Department Labels
# ------------------------------------
variable "department" {
  type        = string
  description = "Department Owner"
  default     = "devops"
}

# ------------------------------------
#  Bucket Terraform State
# ------------------------------------
variable "tfstate_bucket" {
  type        = string
  description = "Name of bucket to store tfstate"
  default     = "laravel-gcp-terraform-state"
}

variable "tfstate_prefix" {
  type        = string
  description = "Path prefix for .tfstate in Bucket"
  default     = "tfstate/terraform.tfstate"
}

# ------------------------------------
#  Service Account Configuration
# ------------------------------------
variable "create_terraform_service_account" {
  type        = bool
  description = "Create a dedicated service account for Terraform"
  default     = false
}
