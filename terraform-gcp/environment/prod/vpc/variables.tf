# ==========================================================================
#  VPC Variables
# ==========================================================================

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "department" {
  description = "Department name for labeling"
  type        = string
  default     = "devops"
}

# --------------------------------------------------------------------------
#  Network CIDR Ranges
# --------------------------------------------------------------------------

variable "public_subnet_cidr" {
  description = "CIDR range for public subnet"
  type        = string
  default     = "10.10.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR range for private subnet"
  type        = string
  default     = "10.10.2.0/24"
}

variable "gke_pod_cidr" {
  description = "CIDR range for GKE pods"
  type        = string
  default     = "10.1.0.0/16"
}

variable "gke_service_cidr" {
  description = "CIDR range for GKE services"
  type        = string
  default     = "10.2.0.0/16"
}

# --------------------------------------------------------------------------
#  Security
# --------------------------------------------------------------------------

variable "allowed_ssh_ranges" {
  description = "IP ranges allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this in production
}
