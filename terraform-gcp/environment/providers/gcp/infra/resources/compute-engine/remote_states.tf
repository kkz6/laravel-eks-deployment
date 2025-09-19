# ==========================================================================
#  Compute Engine: remote_states.tf (Remote State)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Remote state from core infrastructure
#    - VPC, subnets, and other dependencies
# ==========================================================================

# --------------------------------------------------------------------------
#  Core Infrastructure Remote State (Optional)
# --------------------------------------------------------------------------
data "terraform_remote_state" "core" {
  count   = var.use_remote_state ? 1 : 0
  backend = "gcs"

  config = {
    bucket = "${var.tfstate_bucket}-${var.environment[local.env]}"
    prefix = "core/terraform.tfstate"
  }
}

# --------------------------------------------------------------------------
#  Local Values from Remote State or Defaults
# --------------------------------------------------------------------------
locals {
  # Use remote state if available, otherwise use default values
  vpc_id             = var.use_remote_state ? data.terraform_remote_state.core[0].outputs.vpc_id : null
  vpc_name           = var.use_remote_state ? data.terraform_remote_state.core[0].outputs.vpc_name : "default"
  public_subnet_ids  = var.use_remote_state ? data.terraform_remote_state.core[0].outputs.public_subnet_ids : []
  public_subnet_names = var.use_remote_state ? data.terraform_remote_state.core[0].outputs.public_subnet_names : ["default"]
  private_subnet_ids = var.use_remote_state ? data.terraform_remote_state.core[0].outputs.private_subnet_ids : []
  private_subnet_names = var.use_remote_state ? data.terraform_remote_state.core[0].outputs.private_subnet_names : ["default"]
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

# ------------------------------------
#  Remote State Configuration
# ------------------------------------
variable "use_remote_state" {
  type        = bool
  description = "Use remote state from core infrastructure (requires core to be deployed first)"
  default     = false
}
