# Template and Compatibility Fixes

## Issues Fixed

### 1. ✅ **Apple Silicon Compatibility**

**Error:** `Provider registry.terraform.io/hashicorp/template v2.2.0 does not have a package available for your current platform, darwin_arm64.`

**Solution:** Removed deprecated `template` provider from `versions.tf`

```hcl
# REMOVED:
template = {
  source  = "hashicorp/template"
  version = ">= 2.2.0"
}
```

### 2. ✅ **Template Function Syntax Error**

**Error:** `Invalid template control keyword; "http_code" is not a valid template control keyword`

**Solution:** Escaped curl format string in startup script

```bash
# BEFORE:
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health || echo "000")

# AFTER:
HTTP_CODE=$(curl -s -o /dev/null -w "%%{http_code}" http://localhost/health || echo "000")
```

### 3. ✅ **SSH Key File Path Error**

**Error:** `no file exists at "~/.ssh/id_rsa.pub"`

**Solution:** Made SSH keys optional with flexible configuration

```hcl
# BEFORE:
metadata = {
  startup-script = local.startup_script
  ssh-keys       = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
}

# AFTER:
metadata = merge({
  startup-script = local.startup_script
}, var.ssh_public_key != "" ? {
  ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
} : {})
```

## How Template Functions Work

### 🔧 **Terraform Template Syntax**

Terraform's `templatefile()` function uses this syntax:

- `${variable}` - Substitutes Terraform variables
- `%{if condition}...%{endif}` - Conditional blocks
- `%{for item in list}...%{endfor}` - Loops
- `%%{literal}` - Escapes template syntax

### 📝 **Shell vs Template Variables**

```bash
# ✅ CORRECT - Terraform template variables:
DOCKER_IMAGE="${docker_image}"        # Substituted by Terraform
APP_ENV="${app_env}"                  # Substituted by Terraform

# ✅ CORRECT - Shell variables:
USER_HOME=$HOME                       # Shell variable
CURRENT_DATE=$(date)                  # Shell command

# ✅ CORRECT - Escaped curl format:
HTTP_CODE=$(curl -w "%%{http_code}")  # %% escapes to %

# ❌ WRONG - Conflicts with template syntax:
HTTP_CODE=$(curl -w "%{http_code}")   # Terraform thinks this is a template
```

## SSH Key Configuration

### 🔑 **Option 1: Via Terraform Variables**

Add to your `terraform.tfvars`:

```hcl
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ... your-key"
ssh_user       = "ubuntu"
```

### 🔑 **Option 2: Via GCP Console**

1. Go to Compute Engine → VM instances
2. Click on your instance
3. Click "Edit"
4. Add SSH keys in the "Security" section

### 🔑 **Option 3: Via gcloud CLI**

```bash
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"

# Add to existing instance
gcloud compute instances add-metadata INSTANCE_NAME \
  --metadata-from-file ssh-keys=~/.ssh/id_rsa.pub \
  --zone=us-central1-a
```

### 🔑 **Option 4: Via OS Login (Recommended)**

```bash
# Enable OS Login on the project
gcloud compute project-info add-metadata \
  --metadata enable-oslogin=TRUE

# Add your SSH key to OS Login
gcloud compute os-login ssh-keys add \
  --key-file=~/.ssh/id_rsa.pub
```

## Validation Commands

### ✅ **Test Configuration**

```bash
# Validate Terraform syntax
terraform validate

# Check template rendering (dry run)
terraform plan

# Test SSH access (after deployment)
ssh ubuntu@INSTANCE_IP
```

### 🔍 **Debug Template Issues**

```bash
# Check template variables
terraform console
> templatefile("./scripts/startup.sh", {
    docker_image = "test"
    # ... other variables
  })
```

## Best Practices

### 📋 **Template Development**

1. **Test templates separately** before using in Terraform
2. **Escape shell syntax** that conflicts with template syntax
3. **Use descriptive variable names** in templates
4. **Add comments** to explain complex template logic

### 🔒 **SSH Security**

1. **Use strong SSH keys** (RSA 4096-bit or Ed25519)
2. **Enable OS Login** for centralized key management
3. **Restrict SSH access** via firewall rules
4. **Rotate keys regularly** in production

### 🚀 **Deployment**

1. **Validate configuration** before applying
2. **Test in staging** before production
3. **Monitor startup scripts** via Cloud Logging
4. **Use Cloud Shell** for consistent environment

## Troubleshooting

### 🐛 **Common Template Errors**

| Error                              | Cause                                | Solution                       |
| ---------------------------------- | ------------------------------------ | ------------------------------ |
| `Invalid template control keyword` | Shell syntax conflicts with template | Escape with `%%`               |
| `no file exists at path`           | Hardcoded file paths                 | Use variables or make optional |
| `Invalid function argument`        | Missing template variables           | Check variable definitions     |

### 🔧 **Quick Fixes**

```bash
# Clear Terraform state and reinitialize
rm -rf .terraform .terraform.lock.hcl
terraform init

# Check provider compatibility
terraform providers

# Validate after changes
terraform validate
```

Your configuration is now fully compatible with Apple Silicon and includes flexible SSH key management! 🚀
