# ==========================================================================
#  GKE: nxtract-api.tf (Nxtract PDF Extraction API)
# --------------------------------------------------------------------------
#  Description
# --------------------------------------------------------------------------
#    - Separate namespace for Nxtract API management
#    - Kubernetes deployment for Nxtract Python API
#    - Internal ClusterIP service for inter-pod communication
#    - Used by Laravel app for PDF extraction
# ==========================================================================

# --------------------------------------------------------------------------
#  Nxtract API Namespace
# --------------------------------------------------------------------------
resource "kubernetes_namespace" "nxtract_api" {
  metadata {
    name = "nxtract-api"
    labels = {
      name        = "nxtract-api"
      environment = var.environment[local.env]
      project     = "nxtract-pdf-extraction"
    }
  }

  depends_on = [google_container_node_pool.laravel_nodes_private]
}

# --------------------------------------------------------------------------
#  GitHub Registry Secret for Nxtract Namespace
# --------------------------------------------------------------------------
resource "kubernetes_secret" "nxtract_github_registry_secret" {
  metadata {
    name      = "github-registry-secret"
    namespace = kubernetes_namespace.nxtract_api.metadata[0].name
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

  depends_on = [kubernetes_namespace.nxtract_api]
}

# --------------------------------------------------------------------------
#  Nxtract API Deployment
# --------------------------------------------------------------------------
resource "kubernetes_deployment" "nxtract_api" {
  metadata {
    name      = "nxtract-api"
    namespace = kubernetes_namespace.nxtract_api.metadata[0].name
    labels = {
      app       = "nxtract-api"
      component = "api"
      mode      = "http"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app  = "nxtract-api"
        mode = "http"
      }
    }

    template {
      metadata {
        labels = {
          app       = "nxtract-api"
          mode      = "http"
          component = "api"
        }
      }

      spec {
        image_pull_secrets {
          name = kubernetes_secret.nxtract_github_registry_secret.metadata[0].name
        }

        container {
          name              = "nxtract-api"
          image             = var.nxtract_api_image
          image_pull_policy = "Always"

          port {
            container_port = 8000
            name           = "http"
          }

          env {
            name  = "PORT"
            value = "8000"
          }

          env {
            name  = "PYTHONUNBUFFERED"
            value = "1"
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
            http_get {
              path   = "/health"
              port   = 8000
              scheme = "HTTP"
            }
            initial_delay_seconds = 30
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path   = "/health"
              port   = 8000
              scheme = "HTTP"
            }
            initial_delay_seconds = 15
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_secret.nxtract_github_registry_secret,
    kubernetes_namespace.nxtract_api
  ]
}

# --------------------------------------------------------------------------
#  Nxtract API Service (Internal ClusterIP)
# --------------------------------------------------------------------------
resource "kubernetes_service" "nxtract_api_service" {
  metadata {
    name      = "nxtract-api-service"
    namespace = kubernetes_namespace.nxtract_api.metadata[0].name
    labels = {
      app       = "nxtract-api"
      component = "api"
    }
  }

  spec {
    selector = {
      app  = "nxtract-api"
      mode = "http"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 8000
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.nxtract_api]
}
