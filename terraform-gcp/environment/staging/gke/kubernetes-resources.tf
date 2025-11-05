# ==========================================================================
#  GKE: kubernetes-resources.tf (Kubernetes Resources)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Kubernetes namespace, secrets, and deployments
#    - Laravel HTTP, Scheduler, and Horizon deployments
#    - Ingress and services
# ==========================================================================

# --------------------------------------------------------------------------
#  Local Values for Database and Redis Connection
# --------------------------------------------------------------------------
# --------------------------------------------------------------------------
#  Data Sources for Cloud SQL Database Info
# --------------------------------------------------------------------------
data "terraform_remote_state" "cloud_sql" {
  backend = "gcs"
  config = {
    bucket = "zyoshu-terraform-state-staging"
    prefix = "cloud-sql/terraform.tfstate"
  }
  workspace = "staging"
}

locals {
  # Get database connection info from Cloud SQL remote state
  db_host     = try(data.terraform_remote_state.cloud_sql.outputs.database_host, var.db_host)
  db_password = try(data.terraform_remote_state.cloud_sql.outputs.database_password, var.db_password)
  db_user     = try(data.terraform_remote_state.cloud_sql.outputs.database_user, var.db_user)
  db_name     = try(data.terraform_remote_state.cloud_sql.outputs.database_name, var.db_name)
  # Use Kubernetes Redis service instead of VM (more reliable)
  redis_host  = "redis-service.laravel-app.svc.cluster.local"
}

# --------------------------------------------------------------------------
#  Kubernetes Namespace
# --------------------------------------------------------------------------
resource "kubernetes_namespace" "laravel_app" {
  metadata {
    name = "laravel-app"
    labels = {
      name        = "laravel-app"
      environment = var.environment[local.env]
      project     = "laravel-gcp-deployment"
    }
  }

  depends_on = [google_container_node_pool.laravel_nodes]
}

# --------------------------------------------------------------------------
#  Kubernetes Secrets
# --------------------------------------------------------------------------
resource "kubernetes_secret" "laravel_secrets" {
  metadata {
    name      = "laravel-secrets"
    namespace = kubernetes_namespace.laravel_app.metadata[0].name
  }

  data = {
    # Database configuration
    DB_CONNECTION = "mysql"
    DB_HOST       = local.db_host
    DB_PORT       = "3306"
    DB_DATABASE   = local.db_name
    DB_USERNAME   = local.db_user
    DB_PASSWORD   = local.db_password

    # Redis configuration
    REDIS_HOST     = local.redis_host
    REDIS_PORT     = "6379"
    REDIS_PASSWORD = var.redis_password != "" ? var.redis_password : random_password.redis_password[0].result

    # Laravel configuration
    APP_KEY = var.app_key

    # GitHub Container Registry
    GITHUB_USERNAME = var.github_username
    GITHUB_TOKEN    = var.github_token
  }

  type = "Opaque"

  depends_on = [
    kubernetes_namespace.laravel_app,
    google_compute_instance.redis_vm
  ]
}

# --------------------------------------------------------------------------
#  GitHub Registry Secret
# --------------------------------------------------------------------------
resource "kubernetes_secret" "github_registry_secret" {
  metadata {
    name      = "github-registry-secret"
    namespace = kubernetes_namespace.laravel_app.metadata[0].name
  }

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "ghcr.io" = {
          username = var.github_username
          password = var.github_token
          auth     = base64encode("${var.github_username}:${var.github_token}")
        }
      }
    })
  }

  type = "kubernetes.io/dockerconfigjson"

  depends_on = [kubernetes_namespace.laravel_app]
}

# --------------------------------------------------------------------------
#  Laravel ConfigMap
# --------------------------------------------------------------------------
resource "kubernetes_config_map" "laravel_config" {
  metadata {
    name      = "laravel-config"
    namespace = kubernetes_namespace.laravel_app.metadata[0].name
  }

  data = {
    # Application configuration
    APP_ENV     = var.app_env
    APP_DEBUG   = tostring(var.app_debug)
    APP_URL     = var.app_url
    LOG_CHANNEL = "stderr"
    TZ          = "UTC"
    
    # Trust configuration for Kubernetes/GKE environment
    # Note: TRUST_PROXIES="*" causes regex compilation error in Symfony Request class
    # Use specific IP ranges instead
    TRUST_HOSTS   = "false"
    TRUST_PROXIES = "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"

    # Multi-tenant configuration
    BASE_DOMAIN            = var.base_domain
    CENTRAL_DOMAIN         = var.central_domain
    APP_SUBDOMAIN          = var.app_subdomain
    TENANT_ROUTING_ENABLED = "true"

    # Queue configuration
    QUEUE_CONNECTION = "redis"

    # Document AI configuration
    DOC_EXTRACT_API_URL                = var.doc_extract_api_url
    GCP_PROJECT_ID                     = var.gcp_project_id
    GOOGLE_APPLICATION_CREDENTIALS     = var.google_application_credentials
    DOCUMENT_AI_SPLITTING_PROCESSOR_ID = var.document_ai_splitting_processor_id
    DOCUMENT_AI_LOCATION               = var.document_ai_location

    # Google Cloud Storage Configuration for Multi-Tenant
    GOOGLE_CLOUD_PROJECT_ID           = var.project_id
    GOOGLE_CLOUD_STORAGE_BUCKET       = "${var.project_id}-laravel-shared-${var.environment[local.env]}"
    GCS_BUCKET_PREFIX                 = "tenant"
    GCS_BUCKET_LOCATION               = var.gcs_bucket_location
    GCS_STORAGE_CLASS                 = var.gcs_storage_class
    GOOGLE_CLOUD_STORAGE_PATH_PREFIX  = ""
    GOOGLE_CLOUD_STORAGE_API_URI      = ""
    GOOGLE_CLOUD_STORAGE_API_ENDPOINT = ""
    # Note: GOOGLE_CLOUD_KEY_FILE not needed with Workload Identity

    # Migration configuration (for first deployment)
    RUNNING_MIGRATIONS_AND_SEEDERS = var.run_migrations ? "true" : ""
  }

  depends_on = [kubernetes_namespace.laravel_app]
}

# --------------------------------------------------------------------------
#  GCS ConfigMap
# --------------------------------------------------------------------------
resource "kubernetes_config_map" "gcs_config" {
  metadata {
    name      = "gcs-config"
    namespace = kubernetes_namespace.laravel_app.metadata[0].name
  }

  data = {
    GOOGLE_CLOUD_PROJECT_ID            = var.project_id
    GOOGLE_CLOUD_STORAGE_BUCKET        = "${var.project_id}-laravel-shared-${var.environment[local.env]}"
    GCS_BUCKET_PREFIX                  = "tenant"
    GCS_BUCKET_LOCATION                = var.gcs_bucket_location
    GCS_STORAGE_CLASS                  = var.gcs_storage_class
    GOOGLE_CLOUD_STORAGE_PATH_PREFIX   = ""
    GOOGLE_CLOUD_STORAGE_API_URI       = ""
    GOOGLE_CLOUD_STORAGE_API_ENDPOINT  = ""
  }

  depends_on = [kubernetes_namespace.laravel_app]
}

# --------------------------------------------------------------------------
#  Kubernetes Service Account with Workload Identity
# --------------------------------------------------------------------------
resource "kubernetes_service_account" "laravel_service_account" {
  metadata {
    name      = "laravel"
    namespace = kubernetes_namespace.laravel_app.metadata[0].name

    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.laravel_gcs_sa.email
    }

    labels = {
      app         = "laravel"
      environment = var.environment[local.env]
    }
  }

  depends_on = [
    kubernetes_namespace.laravel_app,
    google_service_account.laravel_gcs_sa
  ]
}

# --------------------------------------------------------------------------
#  Laravel HTTP Deployment
# --------------------------------------------------------------------------
resource "kubernetes_deployment" "laravel_http" {
  metadata {
    name      = "laravel-http"
    namespace = kubernetes_namespace.laravel_app.metadata[0].name
    labels = {
      app       = "laravel-http"
      component = "frontend"
      mode      = "http"
    }
  }

  spec {
    replicas = 1 # Single pod setup

    selector {
      match_labels = {
        app  = "laravel-http"
        mode = "http"
      }
    }

    template {
      metadata {
        labels = {
          app       = "laravel-http"
          mode      = "http"
          component = "frontend"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.laravel_service_account.metadata[0].name

        image_pull_secrets {
          name = kubernetes_secret.github_registry_secret.metadata[0].name
        }

        container {
          name              = "laravel-http"
          image             = var.docker_image
          image_pull_policy = "Always"

          port {
            container_port = var.frankenphp_port
            name           = "http"
          }

          env {
            name  = "CONTAINER_MODE"
            value = "http"
          }

          env {
            name  = "OCTANE_SERVER"
            value = "frankenphp"
          }

          # Override GOOGLE_APPLICATION_CREDENTIALS for Workload Identity
          env {
            name  = "GOOGLE_APPLICATION_CREDENTIALS"
            value = ""
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.laravel_secrets.metadata[0].name
            }
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.laravel_config.metadata[0].name
            }
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.gcs_config.metadata[0].name
            }
          }

          resources {
            requests = {
              memory = "256Mi"
              cpu    = "50m"
            }
            limits = {
              memory = "1Gi"
              cpu    = "300m"
            }
          }

          liveness_probe {
            http_get {
              path   = "/health"
              port   = var.frankenphp_port
              scheme = "HTTP"
              http_header {
                name  = "Host"
                value = var.base_domain
              }
            }
            initial_delay_seconds = 60
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path   = "/health"
              port   = var.frankenphp_port
              scheme = "HTTP"
              http_header {
                name  = "Host"
                value = var.base_domain
              }
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          volume_mount {
            name       = "laravel-storage"
            mount_path = "/app/storage"
          }
        }

        volume {
          name = "laravel-storage"
          empty_dir {}
        }
      }
    }
  }

  depends_on = [
    kubernetes_secret.laravel_secrets,
    kubernetes_secret.github_registry_secret,
    kubernetes_config_map.laravel_config
  ]
}

# --------------------------------------------------------------------------
#  Laravel Scheduler Deployment
# --------------------------------------------------------------------------
resource "kubernetes_deployment" "laravel_scheduler" {
  metadata {
    name      = "laravel-scheduler"
    namespace = kubernetes_namespace.laravel_app.metadata[0].name
    labels = {
      app       = "laravel-scheduler"
      component = "scheduler"
      mode      = "scheduler"
    }
  }

  spec {
    replicas = 1

    strategy {
      type = "Recreate" # Ensure only one scheduler runs at a time
    }

    selector {
      match_labels = {
        app  = "laravel-scheduler"
        mode = "scheduler"
      }
    }

    template {
      metadata {
        labels = {
          app       = "laravel-scheduler"
          mode      = "scheduler"
          component = "scheduler"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.laravel_service_account.metadata[0].name

        image_pull_secrets {
          name = kubernetes_secret.github_registry_secret.metadata[0].name
        }

        container {
          name              = "laravel-scheduler"
          image             = var.docker_image
          image_pull_policy = "Always"

          env {
            name  = "CONTAINER_MODE"
            value = "scheduler"
          }

          # Override GOOGLE_APPLICATION_CREDENTIALS for Workload Identity
          env {
            name  = "GOOGLE_APPLICATION_CREDENTIALS"
            value = ""
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.laravel_secrets.metadata[0].name
            }
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.laravel_config.metadata[0].name
            }
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.gcs_config.metadata[0].name
            }
          }

          resources {
            requests = {
              memory = "128Mi"
              cpu    = "25m"
            }
            limits = {
              memory = "512Mi"
              cpu    = "200m"
            }
          }

          liveness_probe {
            exec {
              command = ["/bin/sh", "-c", "ps aux | grep -v grep | grep -q php"]
            }
            initial_delay_seconds = 120
            period_seconds        = 60
            timeout_seconds       = 10
            failure_threshold     = 3
          }

          volume_mount {
            name       = "laravel-storage"
            mount_path = "/app/storage"
          }
        }

        volume {
          name = "laravel-storage"
          empty_dir {}
        }

        restart_policy = "Always"
      }
    }
  }

  depends_on = [
    kubernetes_secret.laravel_secrets,
    kubernetes_secret.github_registry_secret,
    kubernetes_config_map.laravel_config
  ]
}

# --------------------------------------------------------------------------
#  Laravel Horizon Deployment
# --------------------------------------------------------------------------
resource "kubernetes_deployment" "laravel_horizon" {
  metadata {
    name      = "laravel-horizon"
    namespace = kubernetes_namespace.laravel_app.metadata[0].name
    labels = {
      app       = "laravel-horizon"
      component = "worker"
      mode      = "horizon"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app  = "laravel-horizon"
        mode = "horizon"
      }
    }

    template {
      metadata {
        labels = {
          app       = "laravel-horizon"
          mode      = "horizon"
          component = "worker"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.laravel_service_account.metadata[0].name

        image_pull_secrets {
          name = kubernetes_secret.github_registry_secret.metadata[0].name
        }

        container {
          name              = "laravel-horizon"
          image             = var.docker_image
          image_pull_policy = "Always"

          env {
            name  = "CONTAINER_MODE"
            value = "horizon"
          }

          # Override GOOGLE_APPLICATION_CREDENTIALS for Workload Identity
          env {
            name  = "GOOGLE_APPLICATION_CREDENTIALS"
            value = ""
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.laravel_secrets.metadata[0].name
            }
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.laravel_config.metadata[0].name
            }
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.gcs_config.metadata[0].name
            }
          }

          resources {
            requests = {
              memory = "128Mi"
              cpu    = "25m"
            }
            limits = {
              memory = "512Mi"
              cpu    = "200m"
            }
          }

          liveness_probe {
            exec {
              command = ["/bin/sh", "-c", "ps aux | grep -v grep | grep -q php"]
            }
            initial_delay_seconds = 120
            period_seconds        = 60
            timeout_seconds       = 10
            failure_threshold     = 3
          }

          volume_mount {
            name       = "laravel-storage"
            mount_path = "/app/storage"
          }
        }

        volume {
          name = "laravel-storage"
          empty_dir {}
        }
      }
    }
  }

  depends_on = [
    kubernetes_secret.laravel_secrets,
    kubernetes_secret.github_registry_secret,
    kubernetes_config_map.laravel_config
  ]
}

# --------------------------------------------------------------------------
#  Laravel HTTP Service
# --------------------------------------------------------------------------
resource "kubernetes_service" "laravel_http_service" {
  metadata {
    name      = "laravel-http-service"
    namespace = kubernetes_namespace.laravel_app.metadata[0].name
    labels = {
      app       = "laravel-http"
      component = "frontend"
    }
    annotations = {
      "cloud.google.com/neg"            = jsonencode({ ingress = true })
      "cloud.google.com/backend-config" = jsonencode({ default = "laravel-backend-config" })
    }
  }

  spec {
    selector = {
      app  = "laravel-http"
      mode = "http"
    }

    port {
      name        = "http"
      port        = 80
      target_port = var.frankenphp_port
      protocol    = "TCP"
    }

    type = "NodePort"
  }

  depends_on = [kubernetes_deployment.laravel_http]
}

# --------------------------------------------------------------------------
#  Redis Deployment (Kubernetes-based instead of VM)
# --------------------------------------------------------------------------
resource "kubernetes_deployment" "redis" {
  metadata {
    name      = "redis"
    namespace = kubernetes_namespace.laravel_app.metadata[0].name
    labels = {
      app       = "redis"
      component = "cache"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "redis"
      }
    }

    template {
      metadata {
        labels = {
          app       = "redis"
          component = "cache"
        }
      }
      spec {
        containers {
          name  = "redis"
          image = "redis:7.0-alpine"
          ports {
            container_port = 6379
          }
          env {
            name = "REDIS_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.laravel_secrets.metadata[0].name
                key  = "REDIS_PASSWORD"
              }
            }
          }
          command = ["redis-server"]
          args    = ["--requirepass", "$(REDIS_PASSWORD)", "--bind", "0.0.0.0"]
          
          resources {
            requests = {
              memory = "64Mi"
              cpu    = "50m"
            }
            limits = {
              memory = "256Mi"
              cpu    = "200m"
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_secret.laravel_secrets]
}

# --------------------------------------------------------------------------
#  Redis Service
# --------------------------------------------------------------------------
resource "kubernetes_service" "redis_service" {
  metadata {
    name      = "redis-service"
    namespace = kubernetes_namespace.laravel_app.metadata[0].name
    labels = {
      app       = "redis"
      component = "cache"
    }
  }

  spec {
    selector = {
      app = "redis"
    }
    port {
      port        = 6379
      target_port = 6379
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.redis]
}

# --------------------------------------------------------------------------
#  Horizontal Pod Autoscaler for HTTP - DISABLED for single pod setup
# --------------------------------------------------------------------------
# resource "kubernetes_horizontal_pod_autoscaler_v2" "laravel_http_hpa" {
#   metadata {
#     name      = "laravel-http-hpa"
#     namespace = kubernetes_namespace.laravel_app.metadata[0].name
#   }
# 
#   spec {
#     scale_target_ref {
#       api_version = "apps/v1"
#       kind        = "Deployment"
#       name        = kubernetes_deployment.laravel_http.metadata[0].name
#     }
# 
#     min_replicas = var.environment[local.env] == "prod" ? 2 : 1
#     max_replicas = var.environment[local.env] == "prod" ? 10 : 3
# 
#     metric {
#       type = "Resource"
#       resource {
#         name = "cpu"
#         target {
#           type                = "Utilization"
#           average_utilization = 70
#         }
#       }
#     }
# 
#     metric {
#       type = "Resource"
#       resource {
#         name = "memory"
#         target {
#           type                = "Utilization"
#           average_utilization = 80
#         }
#       }
#     }
# 
#     behavior {
#       scale_down {
#         stabilization_window_seconds = 300
#         select_policy                = "Min"
#         policy {
#           type           = "Percent"
#           value          = 10
#           period_seconds = 60
#         }
#       }
# 
#       scale_up {
#         stabilization_window_seconds = 60
#         select_policy                = "Max"
#         policy {
#           type           = "Percent"
#           value          = 50
#           period_seconds = 60
#         }
#       }
#     }
#   }
# 
#   depends_on = [kubernetes_deployment.laravel_http]
# }

# --------------------------------------------------------------------------
#  Horizontal Pod Autoscaler for Horizon - DISABLED for single pod setup
# --------------------------------------------------------------------------
# resource "kubernetes_horizontal_pod_autoscaler_v2" "laravel_horizon_hpa" {
#   metadata {
#     name      = "laravel-horizon-hpa"
#     namespace = kubernetes_namespace.laravel_app.metadata[0].name
#   }
# 
#   spec {
#     scale_target_ref {
#       api_version = "apps/v1"
#       kind        = "Deployment"
#       name        = kubernetes_deployment.laravel_horizon.metadata[0].name
#     }
# 
#     min_replicas = 1
#     max_replicas = var.environment[local.env] == "prod" ? 5 : 2
# 
#     metric {
#       type = "Resource"
#       resource {
#         name = "cpu"
#         target {
#           type                = "Utilization"
#           average_utilization = 80
#         }
#       }
#     }
# 
#     metric {
#       type = "Resource"
#       resource {
#         name = "memory"
#         target {
#           type                = "Utilization"
#           average_utilization = 85
#         }
#       }
#     }
# 
#     behavior {
#       scale_down {
#         stabilization_window_seconds = 300
#         select_policy                = "Min"
#         policy {
#           type           = "Percent"
#           value          = 25
#           period_seconds = 60
#         }
#       }
# 
#       scale_up {
#         stabilization_window_seconds = 60
#         select_policy                = "Max"
#         policy {
#           type           = "Percent"
#           value          = 100
#           period_seconds = 60
#         }
#       }
#     }
#   }
# 
#   depends_on = [kubernetes_deployment.laravel_horizon]
# }

# --------------------------------------------------------------------------
#  Ingress for Multi-Tenant Routing
# --------------------------------------------------------------------------
resource "kubernetes_ingress_v1" "laravel_ingress" {
  metadata {
    name      = "laravel-ingress"
    namespace = kubernetes_namespace.laravel_app.metadata[0].name
    labels = {
      app = "laravel-ingress"
    }
    annotations = {
      "kubernetes.io/ingress.class"                 = "gce"
      "kubernetes.io/ingress.global-static-ip-name" = "laravel-ip-${var.environment[local.env]}"
      "kubernetes.io/ingress.allow-http"             = "true"
      # SSL/TLS handled by Cloudflare - no need for managed certificates
    }
  }

  spec {
    # TLS handled by Cloudflare - ingress serves HTTP only

    rule {
      host = var.app_subdomain != "" ? "${var.app_subdomain}.${var.base_domain}" : var.base_domain
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.laravel_http_service.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }

    # Wildcard domain rule commented out due to regex compilation issues
    # rule {
    #   host = "*.${var.base_domain}" # Tenants use subdomains like tenant1.zyoshu-test.com
    #   http {
    #     path {
    #       path      = "/"
    #       path_type = "Prefix"
    #       backend {
    #         service {
    #           name = kubernetes_service.laravel_http_service.metadata[0].name
    #           port {
    #             number = 80
    #           }
    #         }
    #       }
    #     }
    #   }
    # }
  }

  depends_on = [
    kubernetes_service.laravel_http_service
  ]
}

# --------------------------------------------------------------------------
#  Managed SSL Certificate (using Google Cloud resource instead of k8s manifest)
# --------------------------------------------------------------------------
# Commented out - Using cert-manager with Let's Encrypt instead
# resource "google_compute_managed_ssl_certificate" "laravel_ssl_cert" {
#   name = "laravel-ssl-cert-${var.environment[local.env]}"
#
#   managed {
#     domains = [
#       "${var.app_subdomain}.${var.base_domain}"
#       # Note: Wildcard domains not supported by Google Managed Certificates
#       # Use Cloudflare SSL for wildcard support
#     ]
#   }
#
#   lifecycle {
#     create_before_destroy = true
#   }
# }

# --------------------------------------------------------------------------
#  Global Static IP for Ingress
# --------------------------------------------------------------------------
resource "google_compute_global_address" "laravel_ingress_ip" {
  name         = "laravel-ip-${var.environment[local.env]}"
  description  = "Static IP for Laravel Kubernetes Ingress"
  address_type = "EXTERNAL"

  lifecycle {
    prevent_destroy = true
  }
}
