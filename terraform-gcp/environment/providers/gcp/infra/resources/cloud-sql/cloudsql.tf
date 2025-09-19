# ==========================================================================
#  Cloud SQL: cloudsql.tf (Cloud SQL Instance)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Cloud SQL MySQL instance
#    - Database and user creation
#    - Backup and maintenance configuration
# ==========================================================================

# --------------------------------------------------------------------------
#  Random Password Generation (if not provided)
# --------------------------------------------------------------------------
resource "random_password" "root_password" {
  count   = var.root_password == "" ? 1 : 0
  length  = 16
  special = true
}

resource "random_password" "database_password" {
  count   = var.database_password == "" ? 1 : 0
  length  = 16
  special = true
}

locals {
  root_password     = var.root_password != "" ? var.root_password : random_password.root_password[0].result
  database_password = var.database_password != "" ? var.database_password : random_password.database_password[0].result
}

# --------------------------------------------------------------------------
#  Cloud SQL Instance
# --------------------------------------------------------------------------
resource "google_sql_database_instance" "laravel_db_instance" {
  name                = "laravel-db-${var.environment[local.env]}-${random_id.db_name_suffix.hex}"
  database_version    = var.database_version
  region              = var.gcp_region
  deletion_protection = var.environment[local.env] == "prod" ? true : false

  settings {
    tier              = var.environment[local.env] == "prod" ? var.database_tier : "db-f1-micro"
    availability_type = var.environment[local.env] == "prod" ? var.availability_type : "ZONAL"
    disk_size         = var.environment[local.env] == "prod" ? var.database_disk_size : 10
    disk_type         = var.environment[local.env] == "prod" ? var.database_disk_type : "PD_HDD"
    disk_autoresize   = true
    disk_autoresize_limit = var.environment[local.env] == "prod" ? 100 : 20

    # Backup configuration (simplified for staging)
    backup_configuration {
      enabled                        = var.environment[local.env] == "prod" ? var.database_backup_enabled : false
      start_time                    = var.database_backup_start_time
      location                      = var.gcp_region
      binary_log_enabled           = var.environment[local.env] == "prod" ? true : false
      transaction_log_retention_days = var.environment[local.env] == "prod" ? 7 : 1
      backup_retention_settings {
        retained_backups = var.environment[local.env] == "prod" ? 30 : 3
        retention_unit   = "COUNT"
      }
    }

    # Maintenance window
    maintenance_window {
      day          = var.database_maintenance_window_day
      hour         = var.database_maintenance_window_hour
      update_track = "stable"
    }

    # IP configuration
    ip_configuration {
      ipv4_enabled    = true
      private_network = null
      ssl_mode        = var.require_ssl ? "ENCRYPTED_ONLY" : "ALLOW_UNENCRYPTED_AND_ENCRYPTED"

      dynamic "authorized_networks" {
        for_each = var.authorized_networks
        content {
          name  = authorized_networks.value.name
          value = authorized_networks.value.value
        }
      }
    }

    # Database flags for optimization
    database_flags {
      name  = "slow_query_log"
      value = "on"
    }

    database_flags {
      name  = "long_query_time"
      value = "2"
    }

    database_flags {
      name  = "log_queries_not_using_indexes"
      value = "on"
    }

    # Insights configuration
    insights_config {
      query_insights_enabled  = true
      query_string_length    = 1024
      record_application_tags = true
      record_client_address  = true
    }

    # User labels
    user_labels = local.labels
  }

  # Lifecycle management
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      settings[0].disk_size
    ]
  }

  depends_on = [random_id.db_name_suffix]
}

# --------------------------------------------------------------------------
#  Random suffix for unique naming
# --------------------------------------------------------------------------
resource "random_id" "db_name_suffix" {
  byte_length = 4
}

# --------------------------------------------------------------------------
#  Database Creation
# --------------------------------------------------------------------------
resource "google_sql_database" "laravel_database" {
  name     = var.database_name
  instance = google_sql_database_instance.laravel_db_instance.name

  depends_on = [google_sql_database_instance.laravel_db_instance]
}

# --------------------------------------------------------------------------
#  Database User Creation
# --------------------------------------------------------------------------
resource "google_sql_user" "laravel_user" {
  name     = var.database_user
  instance = google_sql_database_instance.laravel_db_instance.name
  password = local.database_password
  host     = "%"

  depends_on = [google_sql_database_instance.laravel_db_instance]
}

# --------------------------------------------------------------------------
#  Root User Password Update
# --------------------------------------------------------------------------
resource "google_sql_user" "root_user" {
  name     = "root"
  instance = google_sql_database_instance.laravel_db_instance.name
  password = local.root_password
  host     = "%"

  depends_on = [google_sql_database_instance.laravel_db_instance]
}

# --------------------------------------------------------------------------
#  Read Replica (Optional)
# --------------------------------------------------------------------------
resource "google_sql_database_instance" "laravel_db_replica" {
  count               = var.enable_replica ? 1 : 0
  name                = "laravel-db-replica-${var.environment[local.env]}-${random_id.db_name_suffix.hex}"
  master_instance_name = google_sql_database_instance.laravel_db_instance.name
  database_version    = var.database_version
  region              = var.gcp_region
  deletion_protection = false

  replica_configuration {
    failover_target = false
  }

  settings {
    tier              = var.database_tier
    availability_type = "ZONAL"
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = var.require_ssl ? "ENCRYPTED_ONLY" : "ALLOW_UNENCRYPTED_AND_ENCRYPTED"

      dynamic "authorized_networks" {
        for_each = var.authorized_networks
        content {
          name  = authorized_networks.value.name
          value = authorized_networks.value.value
        }
      }
    }

    user_labels = merge(local.labels, {
      replica = "true"
    })
  }

  depends_on = [google_sql_database_instance.laravel_db_instance]
}

# --------------------------------------------------------------------------
#  SSL Certificate
# --------------------------------------------------------------------------
resource "google_sql_ssl_cert" "laravel_ssl_cert" {
  count       = var.require_ssl ? 1 : 0
  common_name = "laravel-ssl-cert"
  instance    = google_sql_database_instance.laravel_db_instance.name

  depends_on = [google_sql_database_instance.laravel_db_instance]
}
