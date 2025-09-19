# ==========================================================================
#  Cloud SQL: variables.tf (Global Environment)
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
#  Cloud SQL Configuration
# ------------------------------------
variable "database_version" {
  type        = string
  description = "Database engine version"
  default     = "MYSQL_8_0"
}

variable "database_tier" {
  type        = string
  description = "Database instance tier"
  default     = "db-f1-micro"
}

variable "database_disk_size" {
  type        = number
  description = "Database disk size in GB"
  default     = 20
}

variable "database_disk_type" {
  type        = string
  description = "Database disk type"
  default     = "PD_SSD"
}

variable "database_backup_enabled" {
  type        = bool
  description = "Enable automated backups"
  default     = true
}

variable "database_backup_start_time" {
  type        = string
  description = "Backup start time (HH:MM format)"
  default     = "03:00"
}

variable "database_maintenance_window_day" {
  type        = number
  description = "Maintenance window day (1-7, Sunday = 7)"
  default     = 7
}

variable "database_maintenance_window_hour" {
  type        = number
  description = "Maintenance window hour (0-23)"
  default     = 4
}

# ------------------------------------
#  Database Configuration
# ------------------------------------
variable "database_name" {
  type        = string
  description = "Name of the database to create"
  default     = "laravel_app"
}

variable "database_user" {
  type        = string
  description = "Database user name"
  default     = "laravel_user"
}

variable "database_password" {
  type        = string
  description = "Database user password"
  sensitive   = true
  default     = ""
}

variable "root_password" {
  type        = string
  description = "Root user password"
  sensitive   = true
  default     = ""
}

# ------------------------------------
#  High Availability
# ------------------------------------
variable "availability_type" {
  type        = string
  description = "Availability type (ZONAL or REGIONAL)"
  default     = "ZONAL"
}

variable "enable_replica" {
  type        = bool
  description = "Enable read replica"
  default     = false
}

# ------------------------------------
#  Networking
# ------------------------------------
variable "require_ssl" {
  type        = bool
  description = "Require SSL connections"
  default     = true
}

variable "authorized_networks" {
  type = list(object({
    name  = string
    value = string
  }))
  description = "List of authorized networks"
  default = [
    {
      name  = "all"
      value = "0.0.0.0/0"
    }
  ]
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
  default     = "cloud-sql/terraform.tfstate"
}
