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
locals {
  # Use variables for database connection (will be provided via terraform.tfvars)
  db_host     = var.db_host
  db_password = var.db_password
  db_user     = var.db_user
  db_name     = var.db_name
  redis_host  = google_compute_instance.redis_vm.network_interface[0].network_ip
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
    DB_HOST      = local.db_host
    DB_PORT      = "3306"
    DB_DATABASE  = local.db_name
    DB_USERNAME  = local.db_user
    DB_PASSWORD  = local.db_password
    
    # Redis configuration
    REDIS_HOST     = local.redis_host
    REDIS_PORT     = "6379"
    REDIS_PASSWORD = ""  # Redis VM doesn't have auth by default
    
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
    APP_ENV   = var.app_env
    APP_DEBUG = tostring(var.app_debug)
    LOG_CHANNEL = "stderr"
    TZ = "UTC"
    
    # Multi-tenant configuration
    BASE_DOMAIN = var.base_domain
    APP_SUBDOMAIN = var.app_subdomain
    TENANT_ROUTING_ENABLED = "true"
    
    # Queue configuration
    QUEUE_CONNECTION = "redis"
    
    # Migration configuration (for first deployment)
    RUNNING_MIGRATIONS_AND_SEEDERS = var.run_migrations ? "true" : ""
  }

  depends_on = [kubernetes_namespace.laravel_app]
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
    replicas = var.environment[local.env] == "prod" ? 2 : 1

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
        image_pull_secrets {
          name = kubernetes_secret.github_registry_secret.metadata[0].name
        }

        container {
          name  = "laravel-http"
          image = var.docker_image
          image_pull_policy = "Always"

          port {
            container_port = var.frankenphp_port
            name          = "http"
          }

          env {
            name  = "CONTAINER_MODE"
            value = "http"
          }
          
          env {
            name  = "OCTANE_SERVER"
            value = "frankenphp"
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

          resources {
            requests = {
              memory = "256Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "512Mi"
              cpu    = "300m"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = var.frankenphp_port
            }
            initial_delay_seconds = 60
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = var.frankenphp_port
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
      type = "Recreate"  # Ensure only one scheduler runs at a time
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
        image_pull_secrets {
          name = kubernetes_secret.github_registry_secret.metadata[0].name
        }

        container {
          name  = "laravel-scheduler"
          image = var.docker_image
          image_pull_policy = "Always"

          env {
            name  = "CONTAINER_MODE"
            value = "scheduler"
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

          resources {
            requests = {
              memory = "64Mi"
              cpu    = "50m"
            }
            limits = {
              memory = "128Mi"
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
        image_pull_secrets {
          name = kubernetes_secret.github_registry_secret.metadata[0].name
        }

        container {
          name  = "laravel-horizon"
          image = var.docker_image
          image_pull_policy = "Always"

          env {
            name  = "CONTAINER_MODE"
            value = "horizon"
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

          resources {
            requests = {
              memory = "64Mi"
              cpu    = "50m"
            }
            limits = {
              memory = "128Mi"
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

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.laravel_http]
}

# --------------------------------------------------------------------------
#  Horizontal Pod Autoscaler for HTTP
# --------------------------------------------------------------------------
resource "kubernetes_horizontal_pod_autoscaler_v2" "laravel_http_hpa" {
  metadata {
    name      = "laravel-http-hpa"
    namespace = kubernetes_namespace.laravel_app.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.laravel_http.metadata[0].name
    }

    min_replicas = var.environment[local.env] == "prod" ? 2 : 1
    max_replicas = var.environment[local.env] == "prod" ? 10 : 3

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }

    behavior {
      scale_down {
        stabilization_window_seconds = 300
        select_policy = "Min"
        policy {
          type          = "Percent"
          value         = 10
          period_seconds = 60
        }
      }

      scale_up {
        stabilization_window_seconds = 60
        select_policy = "Max"
        policy {
          type          = "Percent"
          value         = 50
          period_seconds = 60
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.laravel_http]
}

# --------------------------------------------------------------------------
#  Horizontal Pod Autoscaler for Horizon
# --------------------------------------------------------------------------
resource "kubernetes_horizontal_pod_autoscaler_v2" "laravel_horizon_hpa" {
  metadata {
    name      = "laravel-horizon-hpa"
    namespace = kubernetes_namespace.laravel_app.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.laravel_horizon.metadata[0].name
    }

    min_replicas = 1
    max_replicas = var.environment[local.env] == "prod" ? 5 : 2

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 85
        }
      }
    }

    behavior {
      scale_down {
        stabilization_window_seconds = 300
        select_policy = "Min"
        policy {
          type          = "Percent"
          value         = 25
          period_seconds = 60
        }
      }

      scale_up {
        stabilization_window_seconds = 60
        select_policy = "Max"
        policy {
          type          = "Percent"
          value         = 100
          period_seconds = 60
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.laravel_horizon]
}

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
      "kubernetes.io/ingress.class"                   = "gce"
      "kubernetes.io/ingress.global-static-ip-name"   = "laravel-ip-${var.environment[local.env]}"
      "networking.gke.io/managed-certificates"        = google_compute_managed_ssl_certificate.laravel_ssl_cert.name
      "kubernetes.io/ingress.allow-http"              = "true"
      "nginx.ingress.kubernetes.io/rewrite-target"    = "/"
      "nginx.ingress.kubernetes.io/ssl-redirect"      = "true"
    }
  }

  spec {
    rule {
      host = "${var.app_subdomain}.${var.base_domain}"
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

    rule {
      host = "*.${var.app_subdomain}.${var.base_domain}"
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
  }

  depends_on = [
    kubernetes_service.laravel_http_service,
    google_compute_managed_ssl_certificate.laravel_ssl_cert
  ]
}

# --------------------------------------------------------------------------
#  Managed SSL Certificate (using Google Cloud resource instead of k8s manifest)
# --------------------------------------------------------------------------
resource "google_compute_managed_ssl_certificate" "laravel_ssl_cert" {
  name = "laravel-ssl-cert-${var.environment[local.env]}"

  managed {
    domains = [
      "${var.app_subdomain}.${var.base_domain}"
      # Note: Wildcard domains not supported by Google Managed Certificates
      # Use Cloudflare SSL for wildcard support
    ]
  }

  lifecycle {
    create_before_destroy = true
  }
}

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
