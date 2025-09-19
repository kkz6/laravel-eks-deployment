# ==========================================================================
#  GKE: variables.tf (Global Environment)
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
#  GKE Cluster Configuration
# ------------------------------------
variable "cluster_name" {
  type        = string
  description = "GKE cluster name"
  default     = "laravel-cluster"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version"
  default     = "1.32.6-gke.1060000"
}

variable "node_count" {
  type        = number
  description = "Number of nodes in the default node pool"
  default     = 2
}

variable "node_machine_type" {
  type        = string
  description = "Machine type for GKE nodes"
  default     = "e2-medium"
}

variable "node_disk_size" {
  type        = number
  description = "Disk size for GKE nodes in GB"
  default     = 30
}

variable "node_disk_type" {
  type        = string
  description = "Disk type for GKE nodes"
  default     = "pd-standard"
}

variable "enable_autopilot" {
  type        = bool
  description = "Enable GKE Autopilot mode"
  default     = false
}

variable "enable_autoscaling" {
  type        = bool
  description = "Enable node autoscaling"
  default     = true
}

variable "min_node_count" {
  type        = number
  description = "Minimum number of nodes"
  default     = 1
}

variable "max_node_count" {
  type        = number
  description = "Maximum number of nodes"
  default     = 10
}

# ------------------------------------
#  Redis VM Configuration
# ------------------------------------
variable "redis_machine_type" {
  type        = string
  description = "Machine type for Redis VM"
  default     = "e2-small"
}

variable "redis_disk_size" {
  type        = number
  description = "Disk size for Redis VM in GB"
  default     = 20
}

variable "redis_version" {
  type        = string
  description = "Redis version for VM deployment"
  default     = "7.0"
}

# ------------------------------------
#  Multi-Tenant Domain Configuration
# ------------------------------------
variable "base_domain" {
  type        = string
  description = "Base domain hosted in Cloudflare (e.g., yourdomain.com)"
  default     = ""
}

variable "app_subdomain" {
  type        = string
  description = "Application subdomain (e.g., app for app.yourdomain.com)"
  default     = "app"
}

variable "wildcard_ssl" {
  type        = bool
  description = "Use wildcard SSL certificate for multi-tenant subdomains"
  default     = true
}

# ------------------------------------
#  Docker Configuration
# ------------------------------------
variable "docker_image" {
  type        = string
  description = "Docker image for Laravel application (FrankenPHP-based)"
  default     = "ghcr.io/zyoshu-inc/zyoshu-modular:latest"
}

variable "github_username" {
  type        = string
  description = "GitHub username for container registry authentication"
  default     = ""
}

variable "github_token" {
  type        = string
  description = "GitHub Personal Access Token for container registry authentication"
  sensitive   = true
  default     = ""
}

# ------------------------------------
#  Database Configuration (from Cloud SQL)
# ------------------------------------
variable "db_host" {
  type        = string
  description = "Database host from Cloud SQL"
  default     = ""
}

variable "db_port" {
  type        = string
  description = "Database port"
  default     = "3306"
}

variable "db_name" {
  type        = string
  description = "Database name"
  default     = "laravel_app"
}

variable "db_user" {
  type        = string
  description = "Database user"
  default     = "laravel_user"
}

variable "db_password" {
  type        = string
  description = "Database password"
  sensitive   = true
  default     = ""
}

# ------------------------------------
#  Laravel Application
# ------------------------------------
variable "app_key" {
  type        = string
  description = "Laravel application key"
  sensitive   = true
  default     = "base64:KvkVVCKALENqUruV8z6Lf85poviBolKzDxS+swRxxDk="
}

variable "app_env" {
  type        = string
  description = "Laravel application environment"
  default     = "production"
}

variable "app_debug" {
  type        = bool
  description = "Laravel debug mode"
  default     = false
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
  default     = "gke/terraform.tfstate"
}

# ------------------------------------
#  Additional Variables from terraform.tfvars
# ------------------------------------
variable "database_version" {
  type        = string
  description = "Database version (not used in GKE module)"
  default     = "MYSQL_8_0"
}

variable "database_tier" {
  type        = string
  description = "Database tier (not used in GKE module)"
  default     = "db-f1-micro"
}

variable "database_disk_size" {
  type        = number
  description = "Database disk size (not used in GKE module)"
  default     = 10
}

variable "database_disk_type" {
  type        = string
  description = "Database disk type (not used in GKE module)"
  default     = "PD_HDD"
}

variable "database_name" {
  type        = string
  description = "Database name (not used in GKE module)"
  default     = "laravel_app"
}

variable "database_user" {
  type        = string
  description = "Database user (not used in GKE module)"
  default     = "laravel_user"
}

variable "availability_type" {
  type        = string
  description = "Database availability type (not used in GKE module)"
  default     = "ZONAL"
}

variable "enable_replica" {
  type        = bool
  description = "Enable database replica (not used in GKE module)"
  default     = false
}

variable "require_ssl" {
  type        = bool
  description = "Require SSL for database (not used in GKE module)"
  default     = true
}

variable "enable_https" {
  type        = bool
  description = "Enable HTTPS (handled by ingress)"
  default     = true
}

variable "wildcard_ssl" {
  type        = bool
  description = "Use wildcard SSL certificate for multi-tenant subdomains"
  default     = true
}

variable "tenant_routing_enabled" {
  type        = bool
  description = "Enable tenant-based routing in application"
  default     = true
}

variable "use_remote_state" {
  type        = bool
  description = "Use remote state (not used in simplified structure)"
  default     = false
}

variable "frankenphp_port" {
  type        = number
  description = "Port that FrankenPHP serves on"
  default     = 8000
}
