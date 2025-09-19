# ==========================================================================
#  Compute Engine: redis.tf (Redis Instance for Laravel Horizon)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Redis Memorystore instance for Laravel queues
#    - Used by Laravel Horizon for background job processing
#    - High availability and persistence options
# ==========================================================================

# --------------------------------------------------------------------------
#  Redis Memorystore Instance
# --------------------------------------------------------------------------
resource "google_redis_instance" "laravel_redis" {
  name               = "laravel-redis-${var.environment[local.env]}"
  display_name       = "Laravel Redis for Horizon"
  tier               = var.environment[local.env] == "prod" ? var.redis_tier : "BASIC"
  memory_size_gb     = var.environment[local.env] == "prod" ? var.redis_memory_size : 1
  region             = var.gcp_region
  location_id        = var.gcp_zone
  alternative_location_id = var.environment[local.env] == "prod" ? "${substr(var.gcp_region, 0, length(var.gcp_region)-1)}b" : null

  # Redis version
  redis_version = var.redis_version

  # Network configuration
  authorized_network = var.use_remote_state ? local.vpc_id : "default"

  # Redis configuration parameters
  redis_configs = {
    maxmemory-policy = "allkeys-lru"
    notify-keyspace-events = "Ex"
    timeout = "300"
  }

  # Persistence configuration (for STANDARD_HA tier)
  persistence_config {
    persistence_mode    = var.environment[local.env] == "prod" ? "RDB" : "DISABLED"
    rdb_snapshot_period = var.environment[local.env] == "prod" ? "TWENTY_FOUR_HOURS" : null
    rdb_snapshot_start_time = var.environment[local.env] == "prod" ? "03:00" : null
  }

  # Maintenance policy
  maintenance_policy {
    weekly_maintenance_window {
      day = "SUNDAY"
      start_time {
        hours   = 3
        minutes = 0
        seconds = 0
        nanos   = 0
      }
    }
  }

  # Labels
  labels = merge(local.labels, {
    component = "redis"
    purpose   = "laravel-horizon"
  })

  # Lifecycle management
  lifecycle {
    prevent_destroy = var.environment[local.env] == "prod" ? true : false
  }
}

# --------------------------------------------------------------------------
#  Redis Auth (if enabled)
# --------------------------------------------------------------------------
resource "random_password" "redis_auth" {
  count   = var.redis_auth_enabled ? 1 : 0
  length  = 32
  special = false
}

# Note: Redis AUTH is configured at the application level
# The password would be passed to Laravel via environment variables
