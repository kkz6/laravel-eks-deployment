#!/bin/bash

# ==========================================================================
#  Cloud SQL Diagnostic Script
# --------------------------------------------------------------------------
#  Description: Diagnose Cloud SQL creation issues
# ==========================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

PROJECT_ID="zyoshu-test"
INSTANCE_NAME="laravel-db-stg-17de11c5"

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  Cloud SQL Diagnostic Tool${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo -e "Project: ${GREEN}$PROJECT_ID${NC}"
    echo -e "Instance: ${GREEN}$INSTANCE_NAME${NC}"
    echo ""
}

check_instance_status() {
    echo -e "${YELLOW}Checking Cloud SQL instance status...${NC}"
    
    if gcloud sql instances describe "$INSTANCE_NAME" &>/dev/null; then
        STATUS=$(gcloud sql instances describe "$INSTANCE_NAME" --format="value(state)")
        echo -e "Instance Status: ${GREEN}$STATUS${NC}"
        
        if [ "$STATUS" = "PENDING_CREATE" ]; then
            echo -e "${YELLOW}Instance is still being created...${NC}"
            echo -e "${CYAN}This can take 5-15 minutes for Cloud SQL instances${NC}"
        elif [ "$STATUS" = "RUNNABLE" ]; then
            echo -e "${GREEN}✓ Instance is ready!${NC}"
        else
            echo -e "${RED}⚠ Instance status: $STATUS${NC}"
        fi
        
        # Show instance details
        echo -e "${CYAN}Instance Details:${NC}"
        gcloud sql instances describe "$INSTANCE_NAME" --format="table(
            name,
            databaseVersion,
            region,
            settings.tier,
            settings.dataDiskSizeGb,
            settings.dataDiskType,
            state
        )"
    else
        echo -e "${RED}Instance $INSTANCE_NAME not found${NC}"
    fi
}

check_operations() {
    echo -e "${YELLOW}Checking recent operations...${NC}"
    
    if gcloud sql operations list --instance="$INSTANCE_NAME" --limit=5 &>/dev/null; then
        echo -e "${CYAN}Recent Operations:${NC}"
        gcloud sql operations list --instance="$INSTANCE_NAME" --limit=5 --format="table(
            name,
            operationType,
            status,
            startTime,
            error.code,
            error.message
        )"
    else
        echo -e "${YELLOW}No operations found or instance doesn't exist${NC}"
    fi
}

check_quotas() {
    echo -e "${YELLOW}Checking Cloud SQL quotas...${NC}"
    
    # Check current instances
    CURRENT_INSTANCES=$(gcloud sql instances list --format="value(name)" | wc -l | tr -d ' ')
    echo -e "Current Cloud SQL instances: ${GREEN}$CURRENT_INSTANCES${NC}"
    
    # Check if we're hitting limits
    if [ "$CURRENT_INSTANCES" -ge 100 ]; then
        echo -e "${RED}⚠ Warning: You have many Cloud SQL instances${NC}"
        echo -e "${YELLOW}Consider cleaning up unused instances${NC}"
    fi
}

check_apis() {
    echo -e "${YELLOW}Checking API status...${NC}"
    
    REQUIRED_APIS=(
        "sqladmin.googleapis.com"
        "sql-component.googleapis.com"
        "compute.googleapis.com"
    )
    
    for api in "${REQUIRED_APIS[@]}"; do
        if gcloud services list --enabled --filter="name:$api" --format="value(name)" | grep -q "$api"; then
            echo -e "  ${GREEN}✓ $api enabled${NC}"
        else
            echo -e "  ${RED}✗ $api not enabled${NC}"
            echo -e "    ${YELLOW}Run: gcloud services enable $api${NC}"
        fi
    done
}

check_permissions() {
    echo -e "${YELLOW}Checking IAM permissions...${NC}"
    
    # Get current user
    CURRENT_USER=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    echo -e "Current user: ${GREEN}$CURRENT_USER${NC}"
    
    # Check if user has necessary roles
    REQUIRED_ROLES=(
        "roles/cloudsql.admin"
        "roles/compute.admin"
        "roles/storage.admin"
    )
    
    echo -e "${CYAN}Checking user permissions:${NC}"
    for role in "${REQUIRED_ROLES[@]}"; do
        if gcloud projects get-iam-policy "$PROJECT_ID" --flatten="bindings[].members" --format="value(bindings.role,bindings.members)" | grep -q "$role.*$CURRENT_USER"; then
            echo -e "  ${GREEN}✓ $role${NC}"
        else
            echo -e "  ${YELLOW}? $role (may be inherited)${NC}"
        fi
    done
}

suggest_fixes() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  Suggested Fixes${NC}"
    echo -e "${BLUE}============================================${NC}"
    
    echo -e "${CYAN}1. If instance is PENDING_CREATE:${NC}"
    echo -e "   Wait 10-15 minutes - Cloud SQL instances take time to create"
    echo -e "   Monitor with: gcloud sql instances describe $INSTANCE_NAME"
    echo ""
    
    echo -e "${CYAN}2. If APIs are not enabled:${NC}"
    echo -e "   Run: ./setup-gcp.sh -p $PROJECT_ID"
    echo ""
    
    echo -e "${CYAN}3. If quota issues:${NC}"
    echo -e "   Request quota increase in GCP Console → IAM & Admin → Quotas"
    echo ""
    
    echo -e "${CYAN}4. If permission issues:${NC}"
    echo -e "   Contact project owner to grant Cloud SQL Admin role"
    echo ""
    
    echo -e "${CYAN}5. Clean up and retry:${NC}"
    echo -e "   cd terraform-gcp"
    echo -e "   ./deploy.sh -p $PROJECT_ID -e staging -a destroy"
    echo -e "   ./deploy.sh -p $PROJECT_ID -e staging -a apply"
    echo ""
}

# Main execution
print_header
check_instance_status
check_operations
check_quotas
check_apis
check_permissions
suggest_fixes

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Diagnostic completed!${NC}"
echo -e "${GREEN}============================================${NC}"
