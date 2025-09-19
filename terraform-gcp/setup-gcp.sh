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
REGION="us-central1"
ZONE="us-central1-a"
BILLING_ACCOUNT=""
SKIP_BILLING=false

# Functions
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -p, --project PROJECT      GCP Project ID (required)"
    echo "  -r, --region REGION        GCP Region [default: us-central1]"
    echo "  -z, --zone ZONE            GCP Zone [default: us-central1-a]"
    echo "  -b, --billing ACCOUNT      Billing Account ID (optional)"
    echo "  -s, --skip-billing         Skip billing account setup"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 -p zyoshu-test"
    echo "  $0 -p zyoshu-test -r europe-west1 -z europe-west1-b"
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
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        echo -e "${RED}Error: Google Cloud SDK is not installed${NC}"
        echo -e "${YELLOW}Install with: brew install google-cloud-sdk${NC}"
        exit 1
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
        "roles/cloudsql.admin"
        "roles/storage.admin"
        "roles/iam.serviceAccountUser"
        "roles/resourcemanager.projectEditor"
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
    echo -e "${CYAN}1. Deploy Infrastructure:${NC}"
    echo -e "   cd terraform-gcp"
    echo -e "   ./deploy.sh -p $PROJECT_ID -e staging -a apply"
    echo ""
    echo -e "${CYAN}2. Get Load Balancer IP:${NC}"
    echo -e "   terraform output load_balancer_ip"
    echo ""
    echo -e "${CYAN}3. Configure Cloudflare DNS:${NC}"
    echo -e "   Add A records pointing to your load balancer IP"
    echo ""
    echo -e "${CYAN}4. Test Your Application:${NC}"
    echo -e "   https://app.zyoshu.com"
    echo -e "   https://tenant1.app.zyoshu.com"
    echo ""
    echo -e "${YELLOW}Documentation:${NC}"
    echo -e "   README.md - Main documentation"
    echo -e "   CLOUDFLARE-SETUP.md - DNS configuration guide"
    echo -e "   DATABASE-COST-OPTIMIZATION.md - Cost optimization tips"
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
create_terraform_service_account
verify_setup
show_next_steps

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  GCP Setup completed successfully!${NC}"
echo -e "${GREEN}============================================${NC}"
