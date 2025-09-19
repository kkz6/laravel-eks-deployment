# Apple Silicon (M1/M2) Compatibility Fix

## Issue Fixed

The `hashicorp/template` provider is deprecated and not available for Apple Silicon Macs (darwin_arm64 platform).

### Error Message:

```
Provider registry.terraform.io/hashicorp/template v2.2.0 does not have a package available
for your current platform, darwin_arm64.
```

## Solution Applied

### ✅ **Removed Deprecated Provider**

Updated `terraform-gcp/environment/providers/gcp/infra/resources/compute-engine/versions.tf`:

**Before:**

```hcl
required_providers {
  google = {
    source  = "hashicorp/google"
    version = ">= 4.0.0, < 6.0.0"
  }
  random = {
    source  = "hashicorp/random"
    version = ">= 3.0"
  }
  template = {  # ← REMOVED: Not compatible with Apple Silicon
    source  = "hashicorp/template"
    version = ">= 2.2.0"
  }
}
```

**After:**

```hcl
required_providers {
  google = {
    source  = "hashicorp/google"
    version = ">= 4.0.0, < 6.0.0"
  }
  random = {
    source  = "hashicorp/random"
    version = ">= 3.0"
  }
  # template provider removed - using built-in templatefile() function
}
```

### ✅ **Using Built-in Alternative**

The configuration already uses Terraform's built-in `templatefile()` function instead of the deprecated template provider:

```hcl
# This works without the template provider
locals {
  startup_script = templatefile("${path.module}/scripts/startup.sh", {
    docker_image = var.docker_image
    # ... other variables
  })
}
```

## Platform Compatibility

### ✅ **Now Supports:**

- **Apple Silicon** (M1, M2, M3 Macs) - darwin_arm64
- **Intel Macs** - darwin_amd64
- **Linux** - linux_amd64, linux_arm64
- **Windows** - windows_amd64

### 🔧 **Clean Installation**

If you encounter similar issues in the future:

```bash
# Clean up Terraform state
cd terraform-gcp/environment/providers/gcp/infra/resources/compute-engine
rm -rf .terraform .terraform.lock.hcl

# Re-initialize
terraform init
```

## Alternative Solutions

### Option 1: Use Built-in Functions (Recommended ✅)

```hcl
# Instead of template provider, use:
locals {
  config = templatefile("template.tpl", {
    variable = "value"
  })
}
```

### Option 2: Use Null Provider (If needed)

```hcl
resource "null_resource" "template" {
  provisioner "local-exec" {
    command = "envsubst < template.tpl > output.conf"
    environment = {
      VARIABLE = "value"
    }
  }
}
```

### Option 3: External Data Source

```hcl
data "external" "template" {
  program = ["bash", "generate-config.sh"]
  query = {
    variable = "value"
  }
}
```

## Migration Notes

### ✅ **No Breaking Changes**

- All existing functionality preserved
- Template files work the same way
- Variable substitution works identically
- No changes needed to your `.tf` files

### 📋 **Verification**

After the fix, verify compatibility:

```bash
# Check Terraform version
terraform version

# Validate configuration
terraform validate

# Check provider compatibility
terraform providers
```

## Future-Proofing

### 🚀 **Best Practices**

1. **Avoid Deprecated Providers**: Use built-in functions when possible
2. **Lock Provider Versions**: Specify exact versions in production
3. **Test on Multiple Platforms**: Verify compatibility across platforms
4. **Use Modern Alternatives**: Prefer built-in functions over external providers

### 📚 **Resources**

- [Terraform Built-in Functions](https://www.terraform.io/docs/language/functions/templatefile.html)
- [Provider Compatibility](https://registry.terraform.io/browse/providers)
- [Apple Silicon Support](https://github.com/hashicorp/terraform/issues/27257)

Your configuration is now fully compatible with Apple Silicon Macs! 🍎✅
