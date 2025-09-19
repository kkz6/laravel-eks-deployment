#!/bin/bash

# ==========================================================================
#  Laravel GCP Kubernetes Deployment Script
# --------------------------------------------------------------------------
#  Description: Deploy Laravel with Cloud SQL + Redis VM + GKE
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
ENVIRONMENT="staging"
ACTION="plan"
AUTO_APPROVE=false
PROJECT_ID=""
SKIP_K8S_DEPLOY=false

# Functions
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -e, --environment ENV    Environment (lab|staging|prod) [default: staging]"
    echo "  -a, --action ACTION      Action (plan|apply|destroy) [default: plan]"
    echo "  -p, --project PROJECT    GCP Project ID (required)"
    echo "  -y, --auto-approve       Auto approve terraform apply/destroy"
    echo "  -s, --skip-k8s           Skip Kubernetes manifest deployment"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 -p zyoshu-test -e staging -a plan"
    echo "  $0 -p zyoshu-test -e staging -a apply -y"
    echo "  $0 -p zyoshu-test -e staging -a destroy"
}

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  Laravel Kubernetes Deployment${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo -e "Environment: ${GREEN}$ENVIRONMENT${NC}"
    echo -e "Action: ${GREEN}$ACTION${NC}"
    echo -e "Project ID: ${GREEN}$PROJECT_ID${NC}"
    echo -e "Architecture: ${GREEN}Cloud SQL + Redis VM + GKE${NC}"
    echo ""
}

check_requirements() {
    echo -e "${YELLOW}Checking requirements...${NC}"
    
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}Error: Terraform is not installed${NC}"
        exit 1
    fi
    
    if ! command -v gcloud &> /dev/null; then
        echo -e "${RED}Error: Google Cloud SDK is not installed${NC}"
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}Error: kubectl is not installed${NC}"
        echo -e "${YELLOW}Install with: gcloud components install kubectl${NC}"
        exit 1
    fi
    
    if ! gcloud auth application-default print-access-token &>/dev/null; then
        echo -e "${RED}Error: Application Default Credentials not configured.${NC}"
        echo -e "${YELLOW}Run: ./setup-gcp.sh -p $PROJECT_ID${NC}"
        exit 1
    fi
    
    if [ -z "$PROJECT_ID" ]; then
        echo -e "${RED}Error: GCP Project ID is required${NC}"
        print_usage
        exit 1
    fi
    
    gcloud config set project "$PROJECT_ID"
    echo -e "${GREEN}✓ Requirements check passed${NC}"
}

deploy_terraform_state() {
    echo -e "${YELLOW}Setting up Terraform state...${NC}"
    
    cd environment/providers/gcp/infra/tfstate
    
    terraform init
    terraform workspace select "$ENVIRONMENT" 2>/dev/null || terraform workspace new "$ENVIRONMENT"
    
    if [ "$ACTION" != "destroy" ]; then
        if [ "$AUTO_APPROVE" = true ]; then
            terraform apply -var="project_id=$PROJECT_ID" -auto-approve
        else
            terraform apply -var="project_id=$PROJECT_ID"
        fi
    fi
    
    cd - > /dev/null
    echo -e "${GREEN}✓ Terraform state setup completed${NC}"
}

deploy_cloud_sql() {
    echo -e "${YELLOW}Deploying Cloud SQL database...${NC}"
    
    cd environment/providers/gcp/infra/resources/cloud-sql
    
    terraform init
    terraform workspace select "$ENVIRONMENT" 2>/dev/null || terraform workspace new "$ENVIRONMENT"
    
    case $ACTION in
        plan)
            terraform plan -var="project_id=$PROJECT_ID"
            ;;
        apply)
            if [ "$AUTO_APPROVE" = true ]; then
                terraform apply -var="project_id=$PROJECT_ID" -auto-approve
            else
                terraform apply -var="project_id=$PROJECT_ID"
            fi
            ;;
        destroy)
            if [ "$AUTO_APPROVE" = true ]; then
                terraform destroy -var="project_id=$PROJECT_ID" -auto-approve
            else
                terraform destroy -var="project_id=$PROJECT_ID"
            fi
            ;;
    esac
    
    cd - > /dev/null
    echo -e "${GREEN}✓ Cloud SQL $ACTION completed${NC}"
}

deploy_gke_and_redis() {
    echo -e "${YELLOW}Deploying GKE cluster, Redis VM, and Kubernetes resources...${NC}"
    
    # Get database connection info from Cloud SQL
    if [ "$ACTION" = "apply" ]; then
        echo -e "${CYAN}Getting database connection info...${NC}"
        cd environment/providers/gcp/infra/resources/cloud-sql
        DB_HOST=$(terraform output -raw database_host 2>/dev/null || echo "")
        DB_PASSWORD=$(terraform output -raw database_password 2>/dev/null || echo "")
        DB_USER=$(terraform output -raw database_user 2>/dev/null || echo "")
        DB_NAME=$(terraform output -raw database_name 2>/dev/null || echo "")
        cd - > /dev/null
        
        if [ -n "$DB_HOST" ]; then
            echo -e "${GREEN}✓ Database info retrieved: $DB_HOST${NC}"
            DB_VARS="-var=db_host=$DB_HOST -var=db_password=$DB_PASSWORD -var=db_user=$DB_USER -var=db_name=$DB_NAME"
        else
            echo -e "${YELLOW}⚠ Database info not available - using defaults${NC}"
            DB_VARS=""
        fi
    else
        DB_VARS=""
    fi
    
    cd environment/providers/gcp/infra/resources/gke
    
    terraform init
    terraform workspace select "$ENVIRONMENT" 2>/dev/null || terraform workspace new "$ENVIRONMENT"
    
    # Check if terraform.tfvars exists for additional variables
    TERRAFORM_VARS="-var=project_id=$PROJECT_ID $DB_VARS"
    if [ -f "../../../../terraform.tfvars" ]; then
        TERRAFORM_VARS="$TERRAFORM_VARS -var-file=../../../../terraform.tfvars"
    fi
    
    case $ACTION in
        plan)
            terraform plan $TERRAFORM_VARS
            ;;
        apply)
            if [ "$AUTO_APPROVE" = true ]; then
                terraform apply $TERRAFORM_VARS -auto-approve
            else
                terraform apply $TERRAFORM_VARS
            fi
            ;;
        destroy)
            if [ "$AUTO_APPROVE" = true ]; then
                terraform destroy $TERRAFORM_VARS -auto-approve
            else
                terraform destroy $TERRAFORM_VARS
            fi
            ;;
    esac
    
    cd - > /dev/null
    echo -e "${GREEN}✓ GKE, Redis, and Kubernetes $ACTION completed${NC}"
}

configure_kubectl() {
    if [ "$ACTION" != "apply" ] || [ "$SKIP_K8S_DEPLOY" = true ]; then
        return
    fi
    
    echo -e "${YELLOW}Configuring kubectl...${NC}"
    
    # Ensure gke-gcloud-auth-plugin is in PATH
    GCLOUD_SDK_PATH=$(gcloud info --format="value(installation.sdk_root)" 2>/dev/null || echo "")
    if [ -n "$GCLOUD_SDK_PATH" ]; then
        export PATH="$GCLOUD_SDK_PATH/bin:$PATH"
    fi
    
    if ! command -v gke-gcloud-auth-plugin &> /dev/null; then
        echo -e "${YELLOW}Installing gke-gcloud-auth-plugin...${NC}"
        gcloud components install gke-gcloud-auth-plugin --quiet
        export PATH="$GCLOUD_SDK_PATH/bin:$PATH"
    fi
    
    cd environment/providers/gcp/infra/resources/gke
    
    # Get cluster credentials
    CLUSTER_NAME=$(terraform output -raw cluster_name)
    KUBECTL_COMMAND=$(terraform output -raw kubectl_config_command)
    
    echo -e "${CYAN}Running: $KUBECTL_COMMAND${NC}"
    eval "$KUBECTL_COMMAND"
    
    # Verify connection
    if kubectl cluster-info &>/dev/null; then
        echo -e "${GREEN}✓ kubectl configured successfully${NC}"
    else
        echo -e "${YELLOW}⚠ kubectl configuration issue - continuing with Terraform-managed resources${NC}"
    fi
    
    cd - > /dev/null
}

# Kubernetes resources are now managed by Terraform - no manual deployment needed

show_outputs() {
    if [ "$ACTION" != "apply" ]; then
        return
    fi
    
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  Kubernetes Deployment Outputs${NC}"
    echo -e "${BLUE}============================================${NC}"
    
    # Get database info
    cd environment/providers/gcp/infra/resources/cloud-sql
    DB_HOST=$(terraform output -raw database_host 2>/dev/null || echo "Not available")
    DB_NAME=$(terraform output -raw database_name 2>/dev/null || echo "Not available")
    cd - > /dev/null
    
    # Get GKE and Redis info
    cd environment/providers/gcp/infra/resources/gke
    CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "Not available")
    REDIS_IP=$(terraform output -raw redis_internal_ip 2>/dev/null || echo "Not available")
    KUBECTL_CMD=$(terraform output -raw kubectl_config_command 2>/dev/null || echo "Not available")
    cd - > /dev/null
    
    echo -e "${CYAN}Infrastructure:${NC}"
    echo -e "  Database (Cloud SQL): ${GREEN}$DB_HOST${NC}"
    echo -e "  Redis VM: ${GREEN}$REDIS_IP:6379${NC}"
    echo -e "  GKE Cluster: ${GREEN}$CLUSTER_NAME${NC}"
    echo ""
    
    echo -e "${CYAN}Kubernetes:${NC}"
    echo -e "  Configure kubectl: ${GREEN}$KUBECTL_CMD${NC}"
    echo -e "  Namespace: ${GREEN}laravel-app${NC}"
    echo ""
    
    if [ "$SKIP_K8S_DEPLOY" != true ]; then
        echo -e "${CYAN}Application Status:${NC}"
        kubectl get pods -n laravel-app -o wide 2>/dev/null || echo "  Pods not yet deployed"
        
        echo -e "${CYAN}Ingress Status:${NC}"
        kubectl get ingress -n laravel-app 2>/dev/null || echo "  Ingress not yet ready"
        
        echo -e "${CYAN}Services:${NC}"
        kubectl get services -n laravel-app 2>/dev/null || echo "  Services not yet deployed"
    fi
    
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo -e "1. Wait for ingress IP assignment (5-10 minutes)"
    echo -e "2. Configure Cloudflare DNS with ingress IP"
    echo -e "3. Test your application:"
    echo -e "   https://app.zyoshu.com"
    echo -e "   https://tenant1.app.zyoshu.com"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -a|--action)
            ACTION="$2"
            shift 2
            ;;
        -p|--project)
            PROJECT_ID="$2"
            shift 2
            ;;
        -y|--auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        -s|--skip-k8s)
            SKIP_K8S_DEPLOY=true
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

# Validate inputs
if [[ ! "$ENVIRONMENT" =~ ^(lab|staging|prod)$ ]]; then
    echo -e "${RED}Error: Environment must be lab, staging, or prod${NC}"
    exit 1
fi

if [[ ! "$ACTION" =~ ^(plan|apply|destroy)$ ]]; then
    echo -e "${RED}Error: Action must be plan, apply, or destroy${NC}"
    exit 1
fi

# Set GCP zone based on region
GCP_ZONE="${GCP_REGION:-us-central1}-a"

# Main execution
print_header
check_requirements

case $ACTION in
    destroy)
        echo -e "${RED}WARNING: This will destroy all resources including GKE cluster!${NC}"
        if [ "$AUTO_APPROVE" != true ]; then
            read -p "Are you sure you want to continue? (yes/no): " -r
            if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
                echo "Deployment cancelled."
                exit 0
            fi
        fi
        # Destroy in reverse order
        echo -e "${YELLOW}Note: Please manually delete Kubernetes resources first if needed${NC}"
        deploy_gke_and_redis
        deploy_cloud_sql
        ;;
    *)
        deploy_terraform_state
        deploy_cloud_sql
        deploy_gke_and_redis
        configure_kubectl
        show_outputs
        ;;
esac

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Kubernetes deployment $ACTION completed!${NC}"
echo -e "${GREEN}============================================${NC}"
