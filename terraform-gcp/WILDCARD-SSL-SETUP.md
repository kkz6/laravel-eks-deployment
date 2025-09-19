# Wildcard SSL Certificate Setup for GCP

## Option 1: cert-manager + Let's Encrypt (Recommended) ⭐

### Benefits:

- ✅ **Free** wildcard certificates
- ✅ **Automatic renewal** (every 90 days)
- ✅ **DNS-01 challenge** support for wildcards
- ✅ **Kubernetes native**

### Setup Steps:

#### 1. Install cert-manager

```bash
# Add cert-manager Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

#### 2. Create ClusterIssuer for Let's Encrypt

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-wildcard
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@domain.com
    privateKeySecretRef:
      name: letsencrypt-wildcard-key
    solvers:
      - dns01:
          cloudDNS:
            project: zyoshu-test
            serviceAccountSecretRef:
              name: clouddns-dns01-solver-svc-acct
              key: key.json
```

#### 3. Create Certificate Resource

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-tls
  namespace: laravel-app
spec:
  secretName: wildcard-tls-secret
  issuerRef:
    name: letsencrypt-wildcard
    kind: ClusterIssuer
  dnsNames:
    - "*.gig.codes"
    - "gig.codes"
```

## Option 2: Cloudflare SSL (Easiest) ⚡

### Benefits:

- ✅ **Free** wildcard certificates
- ✅ **Instant** provisioning
- ✅ **No DNS challenges** needed
- ✅ **Cloudflare manages everything**

### Setup:

1. **Move DNS to Cloudflare**
2. **Enable SSL/TLS** in Cloudflare dashboard
3. **Use Cloudflare proxy** (orange cloud)
4. **Get Origin Certificate** for backend

## Option 3: Manual Certificate Upload

### Steps:

1. **Generate wildcard certificate** (Let's Encrypt, commercial CA)
2. **Upload to Google Cloud**:

```bash
gcloud compute ssl-certificates create wildcard-cert \
    --certificate=path/to/cert.pem \
    --private-key=path/to/private-key.pem \
    --global
```

## Recommended Approach for Your Setup

### For Multi-Tenant Laravel App:

**Use cert-manager + Let's Encrypt** because:

- ✅ Supports `*.gig.codes` for all tenants
- ✅ Automatic renewal
- ✅ Works with GKE ingress
- ✅ Free and reliable

### Quick Implementation:

1. **Install cert-manager** in your cluster
2. **Set up DNS-01 solver** with Cloud DNS
3. **Replace Google Managed Certificate** with cert-manager Certificate
4. **All tenant subdomains** will be covered by `*.gig.codes`
