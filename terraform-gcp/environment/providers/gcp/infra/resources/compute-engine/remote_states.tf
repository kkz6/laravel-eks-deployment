# ==========================================================================
#  Compute Engine: remote_states.tf (Remote State)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Remote state from core infrastructure
#    - VPC, subnets, and other dependencies
# ==========================================================================

# --------------------------------------------------------------------------
#  Core Infrastructure Remote State
# --------------------------------------------------------------------------
data "terraform_remote_state" "core" {
  backend = "gcs"

  config = {
    bucket = "${var.tfstate_bucket}-${var.environment[local.env]}"
    prefix = "core/terraform.tfstate"
  }
}

# --------------------------------------------------------------------------
#  Local Values from Remote State
# --------------------------------------------------------------------------
locals {
  vpc_id             = data.terraform_remote_state.core.outputs.vpc_id
  vpc_name           = data.terraform_remote_state.core.outputs.vpc_name
  public_subnet_ids  = data.terraform_remote_state.core.outputs.public_subnet_ids
  public_subnet_names = data.terraform_remote_state.core.outputs.public_subnet_names
  private_subnet_ids = data.terraform_remote_state.core.outputs.private_subnet_ids
  private_subnet_names = data.terraform_remote_state.core.outputs.private_subnet_names
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
  default     = "compute-engine/terraform.tfstate"
}
