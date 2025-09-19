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

# --------------------------------------------------------------------------
#  Get Default VPC for Private IP Configuration
# --------------------------------------------------------------------------
data "google_compute_network" "default" {
  name = "default"
}

# --------------------------------------------------------------------------
#  Private Services Access for Cloud SQL
# --------------------------------------------------------------------------
resource "google_compute_global_address" "private_ip_range" {
  name          = "laravel-private-ip-range-${var.environment[local.env]}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = data.google_compute_network.default.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = data.google_compute_network.default.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]

  depends_on = [google_compute_global_address.private_ip_range]
}

# --------------------------------------------------------------------------
#  Password Generation
# --------------------------------------------------------------------------
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

    # IP configuration - Private IP only for VPC access
    ip_configuration {
      ipv4_enabled                                  = false  # Disable public IP
      private_network                              = data.google_compute_network.default.id
      enable_private_path_for_google_cloud_services = true
      ssl_mode                                     = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"  # Allow non-SSL for initial setup

      # No authorized networks needed for private IP
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

  depends_on = [
    random_id.db_name_suffix,
    google_service_networking_connection.private_vpc_connection
  ]
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
#  Grant Database Privileges to Laravel User (Multi-Tenant Support)
# --------------------------------------------------------------------------
# Note: This script should be run after the database is created
resource "local_file" "grant_privileges_script" {
  filename = "${path.module}/grant-db-privileges.sh"
  content = <<-EOT
#!/bin/bash
# Script to grant database privileges to Laravel user for multi-tenant system

echo "Granting multi-tenant privileges to ${var.database_user}..."

kubectl run mysql-grant-privileges \
  --image=mysql:8.0 \
  --rm -i --restart=Never \
  --namespace=laravel-app \
  -- mysql \
  -h ${google_sql_database_instance.laravel_db_instance.private_ip_address} \
  -u root \
  -p'${local.root_password}' \
  -e "
    -- Grant privileges for multi-tenant system
    GRANT CREATE ON *.* TO '${var.database_user}'@'%';
    GRANT DROP ON *.* TO '${var.database_user}'@'%';
    GRANT ALTER ON *.* TO '${var.database_user}'@'%';
    GRANT INDEX ON *.* TO '${var.database_user}'@'%';
    GRANT REFERENCES ON *.* TO '${var.database_user}'@'%';
    
    -- Grant full privileges on main database
    GRANT ALL PRIVILEGES ON ${var.database_name}.* TO '${var.database_user}'@'%';
    
    -- Grant privileges on all tenant databases (pattern-based)
    GRANT ALL PRIVILEGES ON \`tenant_%\`.* TO '${var.database_user}'@'%';
    GRANT ALL PRIVILEGES ON \`app_%\`.* TO '${var.database_user}'@'%';
    
    -- Flush privileges and show grants
    FLUSH PRIVILEGES;
    SHOW GRANTS FOR '${var.database_user}'@'%';
  "

echo "Multi-tenant privileges granted successfully!"
echo "Laravel user can now:"
echo "  - Create/Drop databases"
echo "  - Manage all tenant databases"
echo "  - Full access to main database: ${var.database_name}"
EOT

  file_permission = "0755"

  depends_on = [
    google_sql_database.laravel_database,
    google_sql_user.laravel_user,
    google_sql_user.root_user
  ]
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
      ipv4_enabled    = false  # Private IP only for replica too
      private_network = data.google_compute_network.default.id
      ssl_mode        = var.require_ssl ? "ENCRYPTED_ONLY" : "ALLOW_UNENCRYPTED_AND_ENCRYPTED"
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
