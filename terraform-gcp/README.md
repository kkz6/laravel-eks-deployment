# Laravel GCP Deployment

Laravel Docker Deployment on Google Cloud Platform using Terraform

![License](https://img.shields.io/github/license/devopscorner/laravel-eks-deployment)

---

## Overview

This Terraform configuration deploys Laravel Docker containers to Google Cloud Platform (GCP) using:

- **Compute Engine**: VM instances for running Docker containers
- **Cloud SQL**: Managed MySQL/PostgreSQL database
- **VPC**: Virtual Private Cloud for network isolation
- **Load Balancer**: HTTP(S) Load Balancer with reserved static IP address
- **Static IP**: Reserved IP address for stable DNS configuration

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        GCP Project                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   Load Balancer │────│   Compute Engine│                │
│  │    (HTTP/HTTPS) │    │   VM Instances  │                │
│  └─────────────────┘    │   (Docker)      │                │
│                         └─────────────────┘                │
│                                │                            │
│                         ┌─────────────────┐                │
│                         │    Cloud SQL    │                │
│                         │   (MySQL/PG)    │                │
│                         └─────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [Docker](https://www.docker.com/get-started)
- GCP Project with billing enabled
- Proper GCP authentication setup (see below)

## Authentication Setup

### **Step 1: Install Google Cloud SDK**

If not already installed:

```bash
# macOS
brew install google-cloud-sdk

# Ubuntu/Debian
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz
tar -xf google-cloud-cli-linux-x86_64.tar.gz
./google-cloud-sdk/install.sh
```

### **Step 2: Authenticate with Google Cloud**

```bash
# 1. Login to your Google Cloud account
gcloud auth login

# 2. Set your project ID (replace with your actual project ID)
gcloud config set project zyoshu-test

# 3. Enable required APIs
gcloud services enable compute.googleapis.com
gcloud services enable sql-component.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable storage-component.googleapis.com

# 4. Set up Application Default Credentials for Terraform
gcloud auth application-default login
```

### **Step 3: Verify Authentication**

```bash
# Check active account
gcloud auth list

# Test authentication
gcloud auth application-default print-access-token

# Verify project access
gcloud projects describe zyoshu-test
```

## Quick Start

1. **Clone and Navigate**

   ```bash
   cd terraform-gcp/environment/providers/gcp/infra
   ```

2. **Initialize Terraform State** (First time only)

   ```bash
   cd tfstate
   terraform init
   terraform plan
   terraform apply
   ```

3. **Deploy Core Infrastructure**

   ```bash
   cd ../core
   terraform init
   terraform plan
   terraform apply
   ```

4. **Deploy Compute Resources**

   ```bash
   cd ../resources/compute-engine
   terraform init
   terraform plan
   terraform apply
   ```

5. **Deploy Database**
   ```bash
   cd ../cloud-sql
   terraform init
   terraform plan
   terraform apply
   ```

## Folder Structure

```
terraform-gcp/
├── README.md
└── environment/
    └── providers/
        └── gcp/
            └── infra/
                ├── core/              # VPC, Subnets, Firewall
                ├── resources/
                │   ├── compute-engine/    # VM instances for Docker
                │   └── cloud-sql/         # Managed database
                └── tfstate/           # Terraform state management
```

## Configuration

### Environment Variables

Create a `.env` file or export these variables:

```bash
export TF_VAR_project_id="your-gcp-project-id"
export TF_VAR_region="us-central1"
export TF_VAR_zone="us-central1-a"
export TF_VAR_environment="staging"

# GitHub Container Registry (for private images)
export TF_VAR_github_username="your-github-username"
export TF_VAR_github_token="ghp_your_personal_access_token"
export TF_VAR_docker_image="ghcr.io/your-username/your-app:latest"
```

### Terraform Variables

Key variables you can customize:

- `project_id`: Your GCP project ID
- `region`: GCP region for resources
- `environment`: Environment tag (staging/prod)
- `machine_type`: VM instance type
- `docker_image`: Laravel Docker image to deploy

## Docker Image

This configuration uses FrankenPHP-based Laravel Docker images:

- Default: `ghcr.io/your-username/your-laravel-app:latest`
- Based on FrankenPHP (high-performance PHP server)
- Built on GitHub and stored in GitHub Container Registry
- No need for separate Nginx - FrankenPHP handles HTTP directly

### GitHub Container Registry Authentication

For private repositories, you'll need:

1. **GitHub Personal Access Token** with `read:packages` scope
2. **Configure authentication** in your `terraform.tfvars`:

   ```hcl
   github_username = "your-github-username"
   github_token    = "ghp_your_personal_access_token"
   docker_image    = "ghcr.io/your-username/your-app:latest"
   ```

3. **Create Personal Access Token**:
   - Go to GitHub Settings > Developer settings > Personal access tokens
   - Generate new token with `read:packages` permission
   - Copy the token (starts with `ghp_`)

### Example GitHub Actions Workflow

Create `.github/workflows/build.yml` in your Laravel repository:

```yaml
name: Build and Push Docker Image

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

## Deployment Environments

- **Staging**: `terraform workspace select staging`
- **Production**: `terraform workspace select prod`

## Security

- VPC with private subnets
- Firewall rules for HTTP/HTTPS only
- Cloud SQL with private IP
- Service accounts with minimal permissions
- Network tags for resource isolation

## Monitoring & Logging

- Cloud Monitoring integration
- Cloud Logging for application logs
- Health checks for load balancer
- Startup scripts for Docker deployment

## Cost Optimization

- Preemptible instances option
- Automatic scaling configuration
- Resource tagging for cost tracking
- Scheduled shutdown for dev environments

## Cleanup

To destroy all resources:

```bash
# Destroy in reverse order
cd terraform-gcp/environment/providers/gcp/infra/resources/cloud-sql
terraform destroy

cd ../compute-engine
terraform destroy

cd ../../core
terraform destroy

cd ../tfstate
terraform destroy
```

## Support

For issues and questions:

- Review Terraform logs
- Check GCP Console for resource status
- Verify service account permissions
- Ensure billing is enabled

## License

Apache v2 - Same as parent project
