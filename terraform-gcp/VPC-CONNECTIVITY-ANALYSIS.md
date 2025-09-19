# VPC Connectivity Analysis & Terraform Fixes

## Current Status

- **GKE Cluster VPC**: `default` network, `default` subnet
- **Cloud SQL VPC**: `projects/zyoshu-test/global/networks/default`
- **Issue**: Laravel pods can't connect to Cloud SQL despite being in same VPC

## Investigation Notes

### 1. VPC Configuration ✅

Both GKE cluster and Cloud SQL are using the `default` VPC network.

### 2. GKE Cluster IP Ranges ✅

- **Pod CIDR**: `10.1.0.0/16` (where Laravel pods get IPs)
- **Services CIDR**: `10.2.0.0/16`
- **Master CIDR**: Not set (public cluster)

**Note**: Laravel pods are getting IPs from `10.1.x.x` range, which explains the pod IPs we saw in logs.

### 3. Firewall Rules Analysis ⚠️

**Key Findings:**

- `default-allow-internal`: Allows `10.128.0.0/9` → Covers `10.128.x.x` but NOT `10.1.x.x`!
- `gke-laravel-cluster-stg-*`: GKE-specific rules for pod CIDR `10.1.0.0/16`
- **ISSUE**: GKE pods (`10.1.x.x`) may not be covered by `default-allow-internal` rule!

**Problem Identified**:
The `default-allow-internal` firewall rule covers `10.128.0.0/9`, but GKE pods are in `10.1.0.0/16`. The range `10.1.x.x` is NOT included in `10.128.0.0/9`.

### 4. IP Range Coverage Analysis ❌

```
10.128.0.0/9 covers: 10.128.0.0 - 10.255.255.255
10.1.0.0/16 covers:  10.1.0.0 - 10.1.255.255
```

**Result**: GKE pod IPs (`10.1.x.x`) are NOT covered by the internal firewall rule!

### 5. Firewall Rule Fix Applied ✅

**Created**: `allow-gke-pods-to-cloudsql` firewall rule

- **Source**: `10.1.0.0/16` (GKE pod CIDR)
- **Target**: All instances (including Cloud SQL)
- **Ports**: `tcp:3306` (MySQL)
- **Priority**: `1000`

### 6. Network Connectivity Tests ❌

**Result**: Firewall rule created but Laravel still gets authentication error.

- Same error: `Access denied for user 'laravel_user'@'10.1.5.34'`
- **Conclusion**: The issue is NOT network connectivity but SSL enforcement.

## Root Cause Analysis

The real issue is **SSL enforcement** on Cloud SQL:

- Cloud SQL is configured with `sslMode: ENCRYPTED_ONLY`
- Laravel is not properly establishing SSL connections
- Manual `mysql` client works because it handles SSL automatically

## Terraform Code Updates Needed

### 1. Add Firewall Rule for GKE-to-CloudSQL ✅

```hcl
resource "google_compute_firewall" "allow_gke_to_cloudsql" {
  name    = "allow-gke-pods-to-cloudsql-${var.environment[local.env]}"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["3306"]
  }

  source_ranges = [var.gke_pod_cidr]  # Need to add this variable: "10.1.0.0/16"

  description = "Allow GKE pods to access Cloud SQL"
}
```

### 2. Fix Cloud SQL SSL Configuration

**Option A**: Disable SSL temporarily for initial setup

```hcl
ip_configuration {
  ipv4_enabled    = false
  private_network = data.google_compute_network.default.id
  ssl_mode        = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"  # Change from ENCRYPTED_ONLY
}
```

**Option B**: Configure Laravel SSL properly (preferred long-term)

```hcl
# In kubernetes secrets, add proper SSL configuration
DB_SSLMODE = "required"
MYSQL_ATTR_SSL_CA = "/path/to/ca-cert"
MYSQL_ATTR_SSL_VERIFY_SERVER_CERT = "false"
```

### 3. Add GKE Pod CIDR Variable

```hcl
variable "gke_pod_cidr" {
  description = "CIDR range for GKE pod IPs"
  type        = string
  default     = "10.1.0.0/16"
}
```

## Manual Fix Applied ✅

**Command Used**:

```bash
gcloud sql instances patch laravel-db-stg-b31b1cb3 --no-require-ssl --project=zyoshu-test
```

**Result**:

- ✅ Migration pod completed successfully: "Nothing to migrate"
- ✅ Horizon pod: 1/1 Running
- 🔄 HTTP pod: Starting up (0/1 Running)
- ❌ Scheduler pod: Error (needs investigation)

## Summary

**Root Cause**: Cloud SQL was configured with SSL enforcement (`requireSsl: true`) but Laravel was not configured to use SSL connections.

**Quick Fix**: Disabled SSL requirement manually using `gcloud sql instances patch --no-require-ssl`

**Status**: Database connectivity restored! Laravel can now connect and migrations work.
