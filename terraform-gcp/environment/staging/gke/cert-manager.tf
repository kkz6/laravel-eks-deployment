# ==========================================================================
#  cert-manager Configuration for Wildcard SSL Certificates
# --------------------------------------------------------------------------
#  Sets up cert-manager with Let's Encrypt for wildcard certificates
# ==========================================================================

# --------------------------------------------------------------------------
#  cert-manager Helm Release
# --------------------------------------------------------------------------
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.13.0"
  namespace  = "cert-manager"

  create_namespace = true
  wait             = true
  wait_for_jobs    = true
  timeout          = 600

  values = [
    yamlencode({
      installCRDs = true
      global = {
        leaderElection = {
          namespace = "cert-manager"
        }
      }
      extraArgs = [
        "--dns01-recursive-nameservers-only",
        "--dns01-recursive-nameservers=8.8.8.8:53,1.1.1.1:53"
      ]
    })
  ]
}

# --------------------------------------------------------------------------
#  Service Account for Cloud DNS Access
# --------------------------------------------------------------------------
resource "google_service_account" "cert_manager_dns" {
  account_id   = "cert-manager-dns-${var.environment[local.env]}"
  display_name = "cert-manager DNS Service Account"
  description  = "Service account for cert-manager to manage Cloud DNS for Let's Encrypt"
}

# Grant Cloud DNS admin permissions
resource "google_project_iam_member" "cert_manager_dns_admin" {
  project = var.project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.cert_manager_dns.email}"
}

# Create service account key
resource "google_service_account_key" "cert_manager_dns_key" {
  service_account_id = google_service_account.cert_manager_dns.name
}

# --------------------------------------------------------------------------
#  Kubernetes Secret for Service Account Key
# --------------------------------------------------------------------------
resource "kubernetes_secret" "cert_manager_dns_key" {
  metadata {
    name      = "clouddns-dns01-solver-svc-acct"
    namespace = "cert-manager"
  }

  data = {
    "key.json" = base64decode(google_service_account_key.cert_manager_dns_key.private_key)
  }

  depends_on = [helm_release.cert_manager]
}

# --------------------------------------------------------------------------
#  Wait for cert-manager CRDs to be ready
# --------------------------------------------------------------------------
resource "time_sleep" "wait_for_cert_manager" {
  depends_on = [helm_release.cert_manager]

  create_duration = "60s"
}

# --------------------------------------------------------------------------
#  Let's Encrypt ClusterIssuer for Wildcard Certificates (using kubectl)
# --------------------------------------------------------------------------
resource "kubectl_manifest" "letsencrypt_wildcard_issuer" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-wildcard
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: ${var.letsencrypt_email}
        privateKeySecretRef:
          name: letsencrypt-wildcard-key
        solvers:
        - dns01:
            cloudDNS:
              project: ${var.project_id}
              serviceAccountSecretRef:
                name: ${kubernetes_secret.cert_manager_dns_key.metadata[0].name}
                key: key.json
  YAML

  depends_on = [
    time_sleep.wait_for_cert_manager,
    kubernetes_secret.cert_manager_dns_key
  ]
}

# --------------------------------------------------------------------------
#  Wildcard Certificate (using kubectl)
# --------------------------------------------------------------------------
resource "kubectl_manifest" "wildcard_certificate" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: wildcard-${var.app_subdomain}-tls
      namespace: ${kubernetes_namespace.laravel_app.metadata[0].name}
    spec:
      secretName: wildcard-${var.app_subdomain}-tls-secret
      issuerRef:
        name: letsencrypt-wildcard
        kind: ClusterIssuer
      dnsNames:
      - "*.${var.app_subdomain}.${var.base_domain}"
      - "${var.app_subdomain}.${var.base_domain}"
  YAML

  depends_on = [
    kubectl_manifest.letsencrypt_wildcard_issuer,
    kubernetes_namespace.laravel_app,
    time_sleep.wait_for_cert_manager
  ]
}
