# ==========================================================================
#  TFState: storage.tf (Google Cloud Storage)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Cloud Storage bucket for Terraform state
#    - Versioning enabled
#    - Lifecycle management
# ==========================================================================

# --------------------------------------------------------------------------
#  Cloud Storage Bucket for Terraform State
# --------------------------------------------------------------------------
resource "google_storage_bucket" "terraform_state" {
  name          = "${var.tfstate_bucket}-${var.environment[local.env]}"
  location      = var.gcp_region
  force_destroy = false

  labels = local.labels

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age                   = 7
      with_state           = "ARCHIVED"
      matches_storage_class = ["NEARLINE"]
    }
    action {
      type = "Delete"
    }
  }

  uniform_bucket_level_access = true
}

# --------------------------------------------------------------------------
#  Get current user for IAM binding
# --------------------------------------------------------------------------
data "google_client_openid_userinfo" "current_user" {}

# --------------------------------------------------------------------------
#  Bucket IAM - Grant access to current user
# --------------------------------------------------------------------------
resource "google_storage_bucket_iam_member" "terraform_state_admin" {
  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.admin"
  member = "user:${data.google_client_openid_userinfo.current_user.email}"

  depends_on = [google_storage_bucket.terraform_state]
}

# --------------------------------------------------------------------------
#  Optional: Service Account for Terraform (if needed)
# --------------------------------------------------------------------------
resource "google_service_account" "terraform_sa" {
  count        = var.create_terraform_service_account ? 1 : 0
  account_id   = "terraform-state-${var.environment[local.env]}"
  display_name = "Terraform State Service Account"
  description  = "Service account for Terraform state management"
}

resource "google_storage_bucket_iam_member" "terraform_sa_admin" {
  count  = var.create_terraform_service_account ? 1 : 0
  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.terraform_sa[0].email}"

  depends_on = [
    google_storage_bucket.terraform_state,
    google_service_account.terraform_sa
  ]
}
