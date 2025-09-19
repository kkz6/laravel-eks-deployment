# ==========================================================================
#  Compute Engine: variables.tf (Global Environment)
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
#  Compute Engine Configuration
# ------------------------------------
variable "machine_type" {
  type        = string
  description = "Machine type for Compute Engine instances"
  default     = "e2-medium"
}

variable "disk_size" {
  type        = number
  description = "Boot disk size in GB"
  default     = 20
}

variable "disk_type" {
  type        = string
  description = "Boot disk type"
  default     = "pd-standard"
}

variable "instance_count" {
  type        = number
  description = "Number of instances to create"
  default     = 2
}

variable "preemptible" {
  type        = bool
  description = "Use preemptible instances for cost savings"
  default     = false
}

# ------------------------------------
#  Docker Configuration
# ------------------------------------
variable "docker_image" {
  type        = string
  description = "Docker image for Laravel application (FrankenPHP-based)"
  default     = "ghcr.io/your-username/your-laravel-app:latest"
}

variable "docker_registry" {
  type        = string
  description = "Docker registry URL"
  default     = "ghcr.io"
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

variable "frankenphp_port" {
  type        = number
  description = "Port that FrankenPHP listens on"
  default     = 80
}

# ------------------------------------
#  Database Configuration
# ------------------------------------
variable "db_host" {
  type        = string
  description = "Database host"
  default     = "laravel-db"
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
  default     = "changeme123!"
}

# ------------------------------------
#  Application Configuration
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
#  HTTPS Configuration
# ------------------------------------
variable "enable_https" {
  type        = bool
  description = "Enable HTTPS with SSL certificate"
  default     = true
}

variable "domain_names" {
  type        = list(string)
  description = "Domain names for SSL certificate"
  default     = []
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

variable "tenant_routing_enabled" {
  type        = bool
  description = "Enable tenant-based routing in FrankenPHP"
  default     = true
}

# ------------------------------------
#  Static IP Configuration
# ------------------------------------
variable "reserve_static_ip" {
  type        = bool
  description = "Reserve a static IP address for the load balancer"
  default     = true
}

variable "static_ip_name" {
  type        = string
  description = "Name for the reserved static IP address"
  default     = ""
}

# ------------------------------------
#  SSH Configuration (Optional)
# ------------------------------------
variable "ssh_public_key" {
  type        = string
  description = "SSH public key for instance access (optional)"
  default     = ""
}

variable "ssh_user" {
  type        = string
  description = "Username for SSH access"
  default     = "ubuntu"
}
