#!/bin/bash

# ==========================================================================
#  GCP Project Setup Script for Laravel Deployment
# --------------------------------------------------------------------------
#  Description: Enable APIs, set quotas, and configure project
# ==========================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
PROJECT_ID=""
REGION="asia-northeast1"
ZONE="asia-northeast1-a"
BILLING_ACCOUNT=""
SKIP_BILLING=false

# Functions
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -p, --project PROJECT      GCP Project ID (required)"
    echo "  -r, --region REGION        GCP Region [default: asia-northeast1]"
    echo "  -z, --zone ZONE            GCP Zone [default: asia-northeast1-a]"
    echo "  -b, --billing ACCOUNT      Billing Account ID (optional)"
    echo "  -s, --skip-billing         Skip billing account setup"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 -p zyoshu-test"
    echo "  $0 -p zyoshu-test -r asia-northeast1 -z asia-northeast1-a"
    echo "  $0 -p zyoshu-test -b 01234A-56789B-CDEFGH"
}

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  GCP Project Setup for Laravel${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo -e "Project ID: ${GREEN}$PROJECT_ID${NC}"
    echo -e "Region: ${GREEN}$REGION${NC}"
    echo -e "Zone: ${GREEN}$ZONE${NC}"
    echo ""
}

check_requirements() {
    echo -e "${YELLOW}Checking requirements...${NC}"
    
    # Detect OS
    OS=$(uname -s)
    ARCH=$(uname -m)
    echo -e "${CYAN}Detected OS: $OS $ARCH${NC}"
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        echo -e "${RED}Error: Google Cloud SDK is not installed${NC}"
        case $OS in
            "Darwin")
                echo -e "${YELLOW}Install with: brew install google-cloud-sdk${NC}"
                echo -e "${YELLOW}Or download from: https://cloud.google.com/sdk/docs/install-sdk${NC}"
                ;;
            "Linux")
                echo -e "${YELLOW}Install with:${NC}"
                echo -e "${CYAN}  curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz${NC}"
                echo -e "${CYAN}  tar -xf google-cloud-cli-linux-x86_64.tar.gz${NC}"
                echo -e "${CYAN}  ./google-cloud-sdk/install.sh${NC}"
                ;;
            *)
                echo -e "${YELLOW}Visit: https://cloud.google.com/sdk/docs/install${NC}"
                ;;
        esac
        exit 1
    fi
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}Error: Terraform is not installed${NC}"
        case $OS in
            "Darwin")
                echo -e "${YELLOW}Install with: brew install terraform${NC}"
                ;;
            "Linux")
                echo -e "${YELLOW}Install with:${NC}"
                echo -e "${CYAN}  wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg${NC}"
                echo -e "${CYAN}  echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com \$(lsb_release -cs) main\" | sudo tee /etc/apt/sources.list.d/hashicorp.list${NC}"
                echo -e "${CYAN}  sudo apt update && sudo apt install terraform${NC}"
                ;;
            *)
                echo -e "${YELLOW}Visit: https://www.terraform.io/downloads${NC}"
                ;;
        esac
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        echo -e "${YELLOW}kubectl not found - will install via gcloud components${NC}"
        gcloud components install kubectl --quiet
    fi
    
    # Check if authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        echo -e "${RED}Error: Not authenticated with gcloud${NC}"
        echo -e "${YELLOW}Run: gcloud auth login${NC}"
        exit 1
    fi
    
    # Check if project exists
    if ! gcloud projects describe "$PROJECT_ID" &>/dev/null; then
        echo -e "${RED}Error: Project '$PROJECT_ID' does not exist or you don't have access${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Requirements check passed${NC}"
}

setup_project_config() {
    echo -e "${YELLOW}Setting up project configuration...${NC}"
    
    # Set default project
    gcloud config set project "$PROJECT_ID"
    echo -e "${GREEN}✓ Set default project to $PROJECT_ID${NC}"
    
    # Set default region and zone
    gcloud config set compute/region "$REGION"
    gcloud config set compute/zone "$ZONE"
    echo -e "${GREEN}✓ Set default region to $REGION and zone to $ZONE${NC}"
}

setup_billing() {
    if [ "$SKIP_BILLING" = true ]; then
        echo -e "${YELLOW}Skipping billing account setup${NC}"
        return
    fi
    
    echo -e "${YELLOW}Checking billing configuration...${NC}"
    
    # Check if billing is enabled
    BILLING_ENABLED=$(gcloud beta billing projects describe "$PROJECT_ID" --format="value(billingEnabled)" 2>/dev/null || echo "false")
    
    if [ "$BILLING_ENABLED" = "true" ]; then
        echo -e "${GREEN}✓ Billing is already enabled for this project${NC}"
        return
    fi
    
    if [ -n "$BILLING_ACCOUNT" ]; then
        echo -e "${YELLOW}Linking billing account...${NC}"
        gcloud beta billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT"
        echo -e "${GREEN}✓ Linked billing account $BILLING_ACCOUNT${NC}"
    else
        echo -e "${YELLOW}Warning: Billing account not specified${NC}"
        echo -e "${YELLOW}You may need to enable billing manually in the GCP Console${NC}"
        echo -e "${CYAN}Available billing accounts:${NC}"
        gcloud beta billing accounts list --format="table(name,displayName,open)" 2>/dev/null || echo "No billing accounts found"
    fi
}

enable_apis() {
    echo -e "${YELLOW}Enabling required APIs...${NC}"
    
    # List of required APIs
    APIS=(
        "compute.googleapis.com"                    # Compute Engine
        "container.googleapis.com"                  # Google Kubernetes Engine
        "sqladmin.googleapis.com"                   # Cloud SQL Admin
        "sql-component.googleapis.com"              # Cloud SQL Component
        "storage-component.googleapis.com"          # Cloud Storage Component
        "storage.googleapis.com"                    # Cloud Storage
        "cloudresourcemanager.googleapis.com"      # Resource Manager
        "iam.googleapis.com"                        # Identity and Access Management
        "logging.googleapis.com"                    # Cloud Logging
        "monitoring.googleapis.com"                 # Cloud Monitoring
        "servicenetworking.googleapis.com"         # Service Networking (for Cloud SQL private IP)
        "cloudkms.googleapis.com"                   # Cloud KMS (for GKE encryption)
    )
    
    echo -e "${CYAN}Enabling APIs (this may take a few minutes)...${NC}"
    
    for api in "${APIS[@]}"; do
        echo -e "  Enabling ${api}..."
        if gcloud services enable "$api" --quiet; then
            echo -e "  ${GREEN}✓ $api enabled${NC}"
        else
            echo -e "  ${RED}✗ Failed to enable $api${NC}"
        fi
    done
    
    echo -e "${GREEN}✓ API enablement completed${NC}"
}

check_quotas() {
    echo -e "${YELLOW}Checking quotas and limits...${NC}"
    
    # Check Cloud SQL quotas
    echo -e "${CYAN}Cloud SQL Quotas:${NC}"
    gcloud sql instances list --format="table(name,databaseVersion,region,gceZone,state)" 2>/dev/null || echo "  No existing instances"
    
    # Check Compute Engine quotas
    echo -e "${CYAN}Compute Engine Quotas:${NC}"
    CPUS_QUOTA=$(gcloud compute project-info describe --format="value(quotas[].limit)" --filter="quotas.metric:CPUS" 2>/dev/null || echo "Unknown")
    INSTANCES_QUOTA=$(gcloud compute project-info describe --format="value(quotas[].limit)" --filter="quotas.metric:INSTANCES" 2>/dev/null || echo "Unknown")
    
    echo -e "  CPUs available: ${GREEN}$CPUS_QUOTA${NC}"
    echo -e "  Instances available: ${GREEN}$INSTANCES_QUOTA${NC}"
    
    # Check current usage
    CURRENT_INSTANCES=$(gcloud compute instances list --format="value(name)" | wc -l)
    echo -e "  Current instances: ${GREEN}$CURRENT_INSTANCES${NC}"
    
    echo -e "${GREEN}✓ Quota check completed${NC}"
}

setup_authentication() {
    echo -e "${YELLOW}Setting up authentication...${NC}"
    
    # Check if Application Default Credentials are set up
    if gcloud auth application-default print-access-token &>/dev/null; then
        echo -e "${GREEN}✓ Application Default Credentials already configured${NC}"
    else
        echo -e "${YELLOW}Setting up Application Default Credentials for Terraform...${NC}"
        echo -e "${CYAN}This will open a browser window for authentication...${NC}"
        
        if gcloud auth application-default login; then
            echo -e "${GREEN}✓ Application Default Credentials configured${NC}"
        else
            echo -e "${RED}✗ Failed to configure Application Default Credentials${NC}"
            echo -e "${YELLOW}You can set this up manually later with: gcloud auth application-default login${NC}"
        fi
    fi
}

install_gke_auth_plugin() {
    echo -e "${YELLOW}Setting up GKE authentication plugin...${NC}"
    
    # Check if gke-gcloud-auth-plugin is available
    if command -v gke-gcloud-auth-plugin &> /dev/null; then
        echo -e "${GREEN}✓ gke-gcloud-auth-plugin already installed${NC}"
        return
    fi
    
    # Install the plugin
    echo -e "${CYAN}Installing gke-gcloud-auth-plugin...${NC}"
    gcloud components install gke-gcloud-auth-plugin --quiet
    
    # Find the plugin location and add to PATH
    GCLOUD_SDK_PATH=$(gcloud info --format="value(installation.sdk_root)")
    if [ -n "$GCLOUD_SDK_PATH" ]; then
        PLUGIN_PATH="$GCLOUD_SDK_PATH/bin"
        echo -e "${CYAN}Adding $PLUGIN_PATH to PATH...${NC}"
        
        # Add to current session
        export PATH="$PLUGIN_PATH:$PATH"
        
        # Add to shell profile for persistence
        SHELL_NAME=$(basename "$SHELL")
        case $SHELL_NAME in
            "bash")
                PROFILE_FILE="$HOME/.bashrc"
                if [ ! -f "$PROFILE_FILE" ]; then
                    PROFILE_FILE="$HOME/.bash_profile"
                fi
                ;;
            "zsh")
                PROFILE_FILE="$HOME/.zshrc"
                ;;
            *)
                PROFILE_FILE="$HOME/.profile"
                ;;
        esac
        
        # Add PATH export to profile if not already present
        if [ -f "$PROFILE_FILE" ] && ! grep -q "gke-gcloud-auth-plugin" "$PROFILE_FILE"; then
            echo "" >> "$PROFILE_FILE"
            echo "# Added by Laravel GCP setup script" >> "$PROFILE_FILE"
            echo "export PATH=\"$PLUGIN_PATH:\$PATH\"" >> "$PROFILE_FILE"
            echo -e "${GREEN}✓ Added to $PROFILE_FILE${NC}"
        fi
    fi
    
    # Verify installation
    if command -v gke-gcloud-auth-plugin &> /dev/null; then
        echo -e "${GREEN}✓ gke-gcloud-auth-plugin installed and available${NC}"
    else
        echo -e "${YELLOW}⚠ Plugin installed but may need manual PATH setup${NC}"
        echo -e "${CYAN}Manual setup: export PATH=\"$PLUGIN_PATH:\$PATH\"${NC}"
    fi
}

create_terraform_service_account() {
    echo -e "${YELLOW}Creating Terraform service account (optional)...${NC}"
    
    SA_NAME="terraform-sa"
    SA_EMAIL="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"
    
    # Check if service account exists
    if gcloud iam service-accounts describe "$SA_EMAIL" &>/dev/null; then
        echo -e "${GREEN}✓ Service account $SA_EMAIL already exists${NC}"
    else
        echo -e "${CYAN}Creating service account...${NC}"
        gcloud iam service-accounts create "$SA_NAME" \
            --display-name="Terraform Service Account" \
            --description="Service account for Terraform deployments"
        echo -e "${GREEN}✓ Created service account $SA_EMAIL${NC}"
    fi
    
    # Grant necessary roles
    echo -e "${CYAN}Granting IAM roles...${NC}"
    ROLES=(
        "roles/compute.admin"
        "roles/container.admin"
        "roles/cloudsql.admin"
        "roles/storage.admin"
        "roles/iam.serviceAccountUser"
        "roles/resourcemanager.projectEditor"
        "roles/servicenetworking.networksAdmin"
    )
    
    for role in "${ROLES[@]}"; do
        gcloud projects add-iam-policy-binding "$PROJECT_ID" \
            --member="serviceAccount:$SA_EMAIL" \
            --role="$role" \
            --quiet &>/dev/null
        echo -e "  ${GREEN}✓ Granted $role${NC}"
    done
    
    echo -e "${GREEN}✓ Service account setup completed${NC}"
    echo -e "${YELLOW}Note: You can use this service account for CI/CD pipelines${NC}"
}

verify_setup() {
    echo -e "${YELLOW}Verifying setup...${NC}"
    
    # Test authentication
    if gcloud auth application-default print-access-token &>/dev/null; then
        echo -e "${GREEN}✓ Authentication working${NC}"
    else
        echo -e "${RED}✗ Authentication issue${NC}"
    fi
    
    # Test API access
    if gcloud compute zones list --limit=1 &>/dev/null; then
        echo -e "${GREEN}✓ Compute Engine API accessible${NC}"
    else
        echo -e "${RED}✗ Compute Engine API issue${NC}"
    fi
    
    if gcloud sql instances list &>/dev/null; then
        echo -e "${GREEN}✓ Cloud SQL API accessible${NC}"
    else
        echo -e "${RED}✗ Cloud SQL API issue${NC}"
    fi
    
    echo -e "${GREEN}✓ Verification completed${NC}"
}

show_next_steps() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  Setup Complete! Next Steps:${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
    echo -e "${CYAN}1. Deploy Kubernetes Infrastructure:${NC}"
    echo -e "   cd terraform-gcp"
    echo -e "   ./deploy.sh -p $PROJECT_ID -e staging -a apply"
    echo ""
    echo -e "${CYAN}2. Check Kubernetes Deployment:${NC}"
    echo -e "   kubectl get pods -n laravel-app"
    echo -e "   kubectl get ingress -n laravel-app"
    echo ""
    echo -e "${CYAN}3. Configure Cloudflare DNS:${NC}"
    echo -e "   Get ingress IP: kubectl get ingress -n laravel-app"
    echo -e "   Add A records: app.zyoshu.com and *.app.zyoshu.com"
    echo ""
    echo -e "${CYAN}4. Test Your Multi-Tenant Application:${NC}"
    echo -e "   https://app.zyoshu.com"
    echo -e "   https://tenant1.app.zyoshu.com"
    echo ""
    echo -e "${YELLOW}Important PATH Setup:${NC}"
    GCLOUD_SDK_PATH=$(gcloud info --format="value(installation.sdk_root)" 2>/dev/null || echo "")
    if [ -n "$GCLOUD_SDK_PATH" ]; then
        echo -e "   Add to your shell profile: export PATH=\"$GCLOUD_SDK_PATH/bin:\$PATH\""
    fi
    echo ""
    echo -e "${YELLOW}Documentation:${NC}"
    echo -e "   README.md - Main documentation"
    echo -e "   KUBERNETES-DEPLOYMENT.md - Kubernetes guide"
    echo -e "   VPC-ONLY-CLOUDSQL.md - Database security guide"
    echo -e "   CLOUDFLARE-SETUP.md - DNS configuration guide"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--project)
            PROJECT_ID="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -z|--zone)
            ZONE="$2"
            shift 2
            ;;
        -b|--billing)
            BILLING_ACCOUNT="$2"
            shift 2
            ;;
        -s|--skip-billing)
            SKIP_BILLING=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            print_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: Project ID is required${NC}"
    print_usage
    exit 1
fi

# Main execution
print_header
check_requirements
setup_project_config
setup_billing
enable_apis

# Wait for APIs to be fully enabled
echo -e "${YELLOW}Waiting for APIs to be fully enabled...${NC}"
sleep 10

check_quotas
setup_authentication
install_gke_auth_plugin
create_terraform_service_account
verify_setup
show_next_steps

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  GCP Setup completed successfully!${NC}"
echo -e "${GREEN}============================================${NC}"
