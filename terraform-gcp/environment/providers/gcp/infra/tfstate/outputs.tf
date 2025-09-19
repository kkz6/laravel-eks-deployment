# ==========================================================================
#  TFState: outputs.tf (Output Terraform)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Return value terraform output
# ==========================================================================

# --------------------------------------------------------------------------
#  Terraform State Bucket
# --------------------------------------------------------------------------
output "terraform_state_bucket" {
  description = "Terraform state bucket name"
  value       = google_storage_bucket.terraform_state.name
}

output "terraform_state_bucket_url" {
  description = "Terraform state bucket URL"
  value       = google_storage_bucket.terraform_state.url
}

# --------------------------------------------------------------------------
#  Environment
# --------------------------------------------------------------------------
output "environment" {
  description = "Environment name"
  value       = var.environment[local.env]
}

output "workspace" {
  description = "Terraform workspace"
  value       = local.env
}

# --------------------------------------------------------------------------
#  Service Account Outputs
# --------------------------------------------------------------------------
output "terraform_service_account_email" {
  description = "Email of the Terraform service account (if created)"
  value       = var.create_terraform_service_account ? google_service_account.terraform_sa[0].email : null
}

output "current_user_email" {
  description = "Email of the current authenticated user"
  value       = data.google_client_openid_userinfo.current_user.email
}
