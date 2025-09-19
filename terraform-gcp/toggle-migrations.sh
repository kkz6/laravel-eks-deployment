#!/bin/bash

# ==========================================================================
#  Toggle Migrations Script
# --------------------------------------------------------------------------
#  Helper script to enable/disable migrations for Laravel deployment
# ==========================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
ACTION=""
TFVARS_FILE="terraform.tfvars"

show_usage() {
    echo -e "${CYAN}Usage: $0 [enable|disable] [--file terraform.tfvars]${NC}"
    echo ""
    echo "Actions:"
    echo "  enable   - Set run_migrations = true (for first deployment)"
    echo "  disable  - Set run_migrations = false (for subsequent deployments)"
    echo ""
    echo "Options:"
    echo "  --file   - Specify tfvars file (default: terraform.tfvars)"
    echo ""
    echo "Examples:"
    echo "  $0 enable                    # Enable migrations"
    echo "  $0 disable                   # Disable migrations"
    echo "  $0 enable --file staging.tfvars  # Use custom tfvars file"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        enable|disable)
            ACTION="$1"
            shift
            ;;
        --file)
            TFVARS_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option '$1'${NC}"
            show_usage
            exit 1
            ;;
    esac
done

# Validate action
if [[ -z "$ACTION" ]]; then
    echo -e "${RED}Error: Action is required${NC}"
    show_usage
    exit 1
fi

# Check if tfvars file exists
if [[ ! -f "$TFVARS_FILE" ]]; then
    echo -e "${RED}Error: File '$TFVARS_FILE' not found${NC}"
    exit 1
fi

# Perform the action
case $ACTION in
    enable)
        echo -e "${YELLOW}Enabling migrations and seeders...${NC}"
        sed -i.bak 's/run_migrations = false/run_migrations = true/' "$TFVARS_FILE"
        sed -i.bak 's/run_migrations = true   # Set to false/run_migrations = true   # Set to false/' "$TFVARS_FILE"
        echo -e "${GREEN}✓ Migrations enabled in $TFVARS_FILE${NC}"
        echo -e "${CYAN}Next deployment will run migrations and seeders${NC}"
        ;;
    disable)
        echo -e "${YELLOW}Disabling migrations and seeders...${NC}"
        sed -i.bak 's/run_migrations = true/run_migrations = false/' "$TFVARS_FILE"
        echo -e "${GREEN}✓ Migrations disabled in $TFVARS_FILE${NC}"
        echo -e "${CYAN}Subsequent deployments will skip migrations${NC}"
        ;;
esac

# Show current status
echo ""
echo -e "${CYAN}Current migration setting:${NC}"
grep "run_migrations" "$TFVARS_FILE" || echo "run_migrations setting not found"

echo ""
echo -e "${YELLOW}Remember to run 'terraform apply' to apply the changes!${NC}"
