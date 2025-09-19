#!/bin/bash

# ==========================================================================
#  Laravel GCP Deployment Script
# --------------------------------------------------------------------------
#  Description: Deploy Laravel application to GCP using Terraform
# ==========================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="staging"
ACTION="plan"
AUTO_APPROVE=false
SKIP_TFSTATE=false
PROJECT_ID=""

# Functions
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -e, --environment ENV    Environment (lab|staging|prod) [default: staging]"
    echo "  -a, --action ACTION      Action (plan|apply|destroy) [default: plan]"
    echo "  -p, --project PROJECT    GCP Project ID (required)"
    echo "  -y, --auto-approve       Auto approve terraform apply/destroy"
    echo "  -s, --skip-tfstate       Skip terraform state setup"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 -p my-gcp-project -e staging -a plan"
    echo "  $0 -p my-gcp-project -e prod -a apply -y"
    echo "  $0 -p my-gcp-project -e staging -a destroy"
}

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  Laravel GCP Deployment${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo -e "Environment: ${GREEN}$ENVIRONMENT${NC}"
    echo -e "Action: ${GREEN}$ACTION${NC}"
    echo -e "Project ID: ${GREEN}$PROJECT_ID${NC}"
    echo ""
}

check_requirements() {
    echo -e "${YELLOW}Checking requirements...${NC}"
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}Error: Terraform is not installed${NC}"
        exit 1
    fi
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        echo -e "${RED}Error: Google Cloud SDK is not installed${NC}"
        exit 1
    fi
    
    # Check if authenticated with gcloud
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        echo -e "${RED}Error: Not authenticated with gcloud. Run the following commands:${NC}"
        echo -e "${YELLOW}  1. gcloud auth login${NC}"
        echo -e "${YELLOW}  2. gcloud config set project $PROJECT_ID${NC}"
        echo -e "${YELLOW}  3. gcloud auth application-default login${NC}"
        exit 1
    fi
    
    # Check if Application Default Credentials are set up
    if ! gcloud auth application-default print-access-token &>/dev/null; then
        echo -e "${RED}Error: Application Default Credentials not configured for Terraform.${NC}"
        echo -e "${YELLOW}Run: gcloud auth application-default login${NC}"
        exit 1
    fi
    
    # Check if project is set
    if [ -z "$PROJECT_ID" ]; then
        echo -e "${RED}Error: GCP Project ID is required${NC}"
        print_usage
        exit 1
    fi
    
    # Set gcloud project
    gcloud config set project "$PROJECT_ID"
    
    echo -e "${GREEN}✓ Requirements check passed${NC}"
}

setup_terraform_state() {
    if [ "$SKIP_TFSTATE" = true ]; then
        echo -e "${YELLOW}Skipping Terraform state setup${NC}"
        return
    fi
    
    echo -e "${YELLOW}Setting up Terraform state...${NC}"
    
    cd environment/providers/gcp/infra/tfstate
    
    # Initialize and apply tfstate
    terraform init
    terraform workspace select "$ENVIRONMENT" 2>/dev/null || terraform workspace new "$ENVIRONMENT"
    
    if [ "$ACTION" = "destroy" ]; then
        echo -e "${YELLOW}Skipping tfstate setup for destroy action${NC}"
    else
        terraform plan -var="project_id=$PROJECT_ID"
        if [ "$AUTO_APPROVE" = true ]; then
            terraform apply -var="project_id=$PROJECT_ID" -auto-approve
        else
            terraform apply -var="project_id=$PROJECT_ID"
        fi
    fi
    
    cd - > /dev/null
    echo -e "${GREEN}✓ Terraform state setup completed${NC}"
}

deploy_core_infrastructure() {
    echo -e "${YELLOW}Deploying core infrastructure...${NC}"
    
    cd environment/providers/gcp/infra/core
    
    # Initialize terraform
    terraform init
    terraform workspace select "$ENVIRONMENT" 2>/dev/null || terraform workspace new "$ENVIRONMENT"
    
    # Check if terraform.tfvars exists, otherwise use default variables
    TERRAFORM_VARS="-var=project_id=$PROJECT_ID"
    if [ -f "../../../../../../terraform.tfvars" ]; then
        TERRAFORM_VARS="$TERRAFORM_VARS -var-file=../../../../../../terraform.tfvars"
    fi
    
    case $ACTION in
        plan)
            terraform plan $TERRAFORM_VARS
            ;;
        apply)
            terraform plan $TERRAFORM_VARS
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
    echo -e "${GREEN}✓ Core infrastructure $ACTION completed${NC}"
}

deploy_cloud_sql() {
    echo -e "${YELLOW}Deploying Cloud SQL database...${NC}"
    
    cd environment/providers/gcp/infra/resources/cloud-sql
    
    # Initialize terraform
    terraform init
    terraform workspace select "$ENVIRONMENT" 2>/dev/null || terraform workspace new "$ENVIRONMENT"
    
    case $ACTION in
        plan)
            terraform plan -var="project_id=$PROJECT_ID"
            ;;
        apply)
            terraform plan -var="project_id=$PROJECT_ID"
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

deploy_compute_engine() {
    echo -e "${YELLOW}Deploying Compute Engine instances...${NC}"
    
    cd environment/providers/gcp/infra/resources/compute-engine
    
    # Initialize terraform
    terraform init
    terraform workspace select "$ENVIRONMENT" 2>/dev/null || terraform workspace new "$ENVIRONMENT"
    
    case $ACTION in
        plan)
            terraform plan -var="project_id=$PROJECT_ID"
            ;;
        apply)
            terraform plan -var="project_id=$PROJECT_ID"
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
    echo -e "${GREEN}✓ Compute Engine $ACTION completed${NC}"
}

show_outputs() {
    if [ "$ACTION" != "apply" ]; then
        return
    fi
    
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  Deployment Outputs${NC}"
    echo -e "${BLUE}============================================${NC}"
    
    # Get load balancer IP
    cd environment/providers/gcp/infra/resources/compute-engine
    LOAD_BALANCER_IP=$(terraform output -raw load_balancer_ip 2>/dev/null || echo "Not available")
    LOAD_BALANCER_URL=$(terraform output -raw load_balancer_url 2>/dev/null || echo "Not available")
    cd - > /dev/null
    
    # Get database connection info
    cd environment/providers/gcp/infra/resources/cloud-sql
    DB_HOST=$(terraform output -raw database_host 2>/dev/null || echo "Not available")
    DB_NAME=$(terraform output -raw database_name 2>/dev/null || echo "Not available")
    DB_USER=$(terraform output -raw database_user 2>/dev/null || echo "Not available")
    cd - > /dev/null
    
    echo -e "Load Balancer IP: ${GREEN}$LOAD_BALANCER_IP${NC}"
    echo -e "Application URL: ${GREEN}$LOAD_BALANCER_URL${NC}"
    echo -e "Database Host: ${GREEN}$DB_HOST${NC}"
    echo -e "Database Name: ${GREEN}$DB_NAME${NC}"
    echo -e "Database User: ${GREEN}$DB_USER${NC}"
    echo ""
    echo -e "${YELLOW}Note: It may take a few minutes for the application to be fully available${NC}"
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
        -s|--skip-tfstate)
            SKIP_TFSTATE=true
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

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(lab|staging|prod)$ ]]; then
    echo -e "${RED}Error: Environment must be lab, staging, or prod${NC}"
    exit 1
fi

# Validate action
if [[ ! "$ACTION" =~ ^(plan|apply|destroy)$ ]]; then
    echo -e "${RED}Error: Action must be plan, apply, or destroy${NC}"
    exit 1
fi

# Main execution
print_header
check_requirements

case $ACTION in
    destroy)
        echo -e "${RED}WARNING: This will destroy all resources!${NC}"
        if [ "$AUTO_APPROVE" != true ]; then
            read -p "Are you sure you want to continue? (yes/no): " -r
            if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
                echo "Deployment cancelled."
                exit 0
            fi
        fi
        # Destroy in reverse order
        deploy_compute_engine
        deploy_cloud_sql
        deploy_core_infrastructure
        ;;
    *)
        setup_terraform_state
        deploy_core_infrastructure
        deploy_cloud_sql
        deploy_compute_engine
        show_outputs
        ;;
esac

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Deployment $ACTION completed successfully!${NC}"
echo -e "${GREEN}============================================${NC}"
