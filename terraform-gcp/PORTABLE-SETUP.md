# Portable Setup Guide - Run on Any Machine

## 🖥️ **Cross-Platform Support**

The setup script now works on:

- ✅ **macOS** (Intel & Apple Silicon)
- ✅ **Linux** (Ubuntu, Debian, CentOS, etc.)
- ✅ **Windows** (via WSL2)
- ✅ **Cloud Shell** (Google Cloud)
- ✅ **CI/CD Systems** (GitHub Actions, GitLab CI, etc.)

## 🚀 **One-Command Setup**

### **For Any New Machine:**

```bash
# Clone the repository
git clone https://github.com/your-repo/laravel-eks-deployment.git
cd laravel-eks-deployment/terraform-gcp

# Run the portable setup script
./setup-gcp.sh -p zyoshu-test
```

## 🔧 **What the Script Automatically Handles:**

### **1. OS Detection & Tool Installation:**

```bash
# Detects your OS and provides specific install commands
# macOS: brew install google-cloud-sdk terraform
# Linux: apt/yum package manager instructions
# Windows: WSL2 compatible instructions
```

### **2. Required Tools Installation:**

- ✅ **Google Cloud SDK**: Automatically detects and guides installation
- ✅ **Terraform**: OS-specific installation instructions
- ✅ **kubectl**: Installed via gcloud components
- ✅ **gke-gcloud-auth-plugin**: Automatically installed and configured

### **3. PATH Configuration:**

```bash
# Automatically adds to your shell profile:
# ~/.zshrc (zsh)
# ~/.bashrc or ~/.bash_profile (bash)
# ~/.profile (other shells)

export PATH="/path/to/gcloud/bin:$PATH"
```

### **4. GCP Project Setup:**

- ✅ **API Enablement**: All 12+ required APIs
- ✅ **Authentication**: Application Default Credentials
- ✅ **Project Configuration**: Region, zone settings
- ✅ **Service Accounts**: Terraform and GKE service accounts
- ✅ **Permissions**: All necessary IAM roles

## 📋 **APIs Automatically Enabled:**

```bash
compute.googleapis.com                    # Compute Engine & VMs
container.googleapis.com                  # Google Kubernetes Engine
sqladmin.googleapis.com                   # Cloud SQL Admin
sql-component.googleapis.com              # Cloud SQL Component
storage-component.googleapis.com          # Cloud Storage
storage.googleapis.com                    # Terraform state
cloudresourcemanager.googleapis.com       # Project management
iam.googleapis.com                        # Service accounts
logging.googleapis.com                    # Application logs
monitoring.googleapis.com                 # Performance metrics
servicenetworking.googleapis.com          # Cloud SQL private IP
cloudkms.googleapis.com                   # GKE encryption
```

## 🔑 **Authentication Setup:**

### **Interactive Setup (Default):**

```bash
# The script will prompt for:
gcloud auth login                    # Your Google account
gcloud auth application-default login  # Terraform credentials
```

### **CI/CD Setup (Service Account):**

```bash
# For automated environments:
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
./setup-gcp.sh -p zyoshu-test -s  # Skip interactive billing setup
```

## 🌍 **Platform-Specific Instructions:**

### **🍎 macOS (Intel & Apple Silicon):**

```bash
# Prerequisites (if not installed):
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install google-cloud-sdk terraform

# Run setup
./setup-gcp.sh -p zyoshu-test
```

### **🐧 Linux (Ubuntu/Debian):**

```bash
# Prerequisites:
sudo apt update
sudo apt install -y curl wget unzip

# Google Cloud SDK
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz
tar -xf google-cloud-cli-linux-x86_64.tar.gz
./google-cloud-sdk/install.sh

# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Run setup
./setup-gcp.sh -p zyoshu-test
```

### **🪟 Windows (WSL2):**

```bash
# Enable WSL2 and install Ubuntu
wsl --install -d Ubuntu

# Inside WSL2, follow Linux instructions above
./setup-gcp.sh -p zyoshu-test
```

### **☁️ Google Cloud Shell:**

```bash
# Everything is pre-installed!
git clone https://github.com/your-repo/laravel-eks-deployment.git
cd laravel-eks-deployment/terraform-gcp
./setup-gcp.sh -p zyoshu-test
```

## 🔄 **Team Setup Workflow:**

### **For New Team Members:**

```bash
# 1. Clone repository
git clone https://github.com/your-repo/laravel-eks-deployment.git
cd laravel-eks-deployment/terraform-gcp

# 2. Run setup (handles everything)
./setup-gcp.sh -p zyoshu-test

# 3. Deploy application
./deploy.sh -p zyoshu-test -e staging -a apply

# 4. Verify deployment
kubectl get pods -n laravel-app
```

### **For CI/CD Pipelines:**

```yaml
# GitHub Actions example
- name: Setup GCP
  run: |
    echo ${{ secrets.GCP_SA_KEY }} | base64 -d > gcp-key.json
    export GOOGLE_APPLICATION_CREDENTIALS="gcp-key.json"
    ./setup-gcp.sh -p zyoshu-test -s

- name: Deploy Infrastructure
  run: ./deploy.sh -p zyoshu-test -e staging -a apply -y
```

## 🛠️ **Troubleshooting Different Machines:**

### **PATH Issues:**

```bash
# If kubectl or gke-gcloud-auth-plugin not found:
export PATH="$(gcloud info --format='value(installation.sdk_root)')/bin:$PATH"

# Make permanent:
echo 'export PATH="$(gcloud info --format='value(installation.sdk_root)')/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### **Permission Issues:**

```bash
# If script not executable:
chmod +x setup-gcp.sh deploy.sh

# If gcloud not in PATH:
source ~/.zshrc  # or ~/.bashrc
```

### **Network Issues:**

```bash
# If API enablement fails:
gcloud services enable container.googleapis.com --async
gcloud services enable servicenetworking.googleapis.com --async
# Wait 2-3 minutes, then retry
```

## 📦 **Docker Installation (If Needed):**

### **macOS:**

```bash
brew install --cask docker
# Or download Docker Desktop
```

### **Linux:**

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
sudo usermod -aG docker $USER
```

## 🎯 **Environment Variables (Optional):**

For consistent setup across machines:

```bash
# Create .env file
cat > .env << EOF
export TF_VAR_project_id="zyoshu-test"
export TF_VAR_gcp_region="us-central1"
export TF_VAR_gcp_zone="us-central1-a"
export TF_VAR_github_username="kkz6"
export TF_VAR_github_token="ghp_your_token"
export TF_VAR_docker_image="ghcr.io/zyoshu-inc/zyoshu-modular:latest"
EOF

# Source before deployment
source .env
./deploy.sh -p zyoshu-test -e staging -a apply
```

## 🔐 **Security for Multiple Machines:**

### **Service Account Key (Recommended for CI/CD):**

```bash
# Create service account key
gcloud iam service-accounts keys create terraform-key.json \
  --iam-account=terraform-sa@zyoshu-test.iam.gserviceaccount.com

# Use on other machines
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/terraform-key.json"
```

### **Personal Account (Development):**

```bash
# Each developer runs:
gcloud auth login
gcloud auth application-default login
```

## 🚀 **Quick Start for New Machine:**

```bash
# 1. Prerequisites check
./setup-gcp.sh -p zyoshu-test

# 2. Deploy everything
./deploy.sh -p zyoshu-test -e staging -a apply

# 3. Verify (may need to add PATH)
export PATH="$(gcloud info --format='value(installation.sdk_root)')/bin:$PATH"
kubectl get pods -n laravel-app

# 4. Get ingress IP for DNS
kubectl get ingress -n laravel-app
```

## 💡 **Best Practices:**

### **For Development Teams:**

1. **Standardize**: Use the same setup script across all machines
2. **Document**: Keep project-specific variables in README
3. **Version Control**: Include setup scripts in repository
4. **Test**: Verify setup on different OS types

### **For Production:**

1. **Service Accounts**: Use dedicated service accounts
2. **Environment Separation**: Different projects for staging/prod
3. **Access Control**: Limit who can run setup scripts
4. **Monitoring**: Set up alerts for infrastructure changes

Your setup script is now **completely portable** and will work consistently across any machine or environment! 🌍✅
