# ==========================================================================
#  cert-manager Configuration for Wildcard SSL Certificates
# --------------------------------------------------------------------------
#  Sets up cert-manager with Let's Encrypt using Cloudflare DNS-01 challenge
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
#  Kubernetes Secret for Cloudflare API Token
# --------------------------------------------------------------------------
resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token-secret"
    namespace = "cert-manager"
  }

  data = {
    "api-token" = var.cloudflare_api_token
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
#  Let's Encrypt ClusterIssuer with Cloudflare DNS-01 - Production
# --------------------------------------------------------------------------
resource "kubectl_manifest" "letsencrypt_prod_issuer" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: ${var.letsencrypt_email}
        privateKeySecretRef:
          name: letsencrypt-prod-key
        solvers:
        - dns01:
            cloudflare:
              apiTokenSecretRef:
                name: ${kubernetes_secret.cloudflare_api_token.metadata[0].name}
                key: api-token
  YAML

  depends_on = [
    time_sleep.wait_for_cert_manager,
    kubernetes_secret.cloudflare_api_token
  ]
}

# --------------------------------------------------------------------------
#  Let's Encrypt ClusterIssuer with Cloudflare DNS-01 - Staging (for testing)
# --------------------------------------------------------------------------
resource "kubectl_manifest" "letsencrypt_staging_issuer" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-staging
    spec:
      acme:
        server: https://acme-staging-v02.api.letsencrypt.org/directory
        email: ${var.letsencrypt_email}
        privateKeySecretRef:
          name: letsencrypt-staging-key
        solvers:
        - dns01:
            cloudflare:
              apiTokenSecretRef:
                name: ${kubernetes_secret.cloudflare_api_token.metadata[0].name}
                key: api-token
  YAML

  depends_on = [
    time_sleep.wait_for_cert_manager,
    kubernetes_secret.cloudflare_api_token
  ]
}

# --------------------------------------------------------------------------
#  Wildcard Certificate for *.subdomain.domain.com
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
        name: letsencrypt-prod
        kind: ClusterIssuer
      commonName: '*.${var.app_subdomain}.${var.base_domain}'
      dnsNames:
      - '*.${var.app_subdomain}.${var.base_domain}'
      - '${var.app_subdomain}.${var.base_domain}'
  YAML

  depends_on = [
    kubectl_manifest.letsencrypt_prod_issuer,
    kubernetes_namespace.laravel_app,
    time_sleep.wait_for_cert_manager
  ]
}

# --------------------------------------------------------------------------
#  Instructions for creating Cloudflare API Token:
# --------------------------------------------------------------------------
# 1. Go to Cloudflare Dashboard > My Profile > API Tokens
# 2. Click "Create Token"
# 3. Use "Custom token" template with these permissions:
#    - Zone > DNS > Edit
#    - Zone > Zone > Read
# 4. Zone Resources: Include > Specific zone > your-domain.com
# 5. Create token and add it to terraform.tfvars:
#    cloudflare_api_token = "your-token-here"
# --------------------------------------------------------------------------