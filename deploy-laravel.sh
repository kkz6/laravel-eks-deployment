#!/bin/bash

# ==========================================================================
#  Laravel Application Deployment Script
# --------------------------------------------------------------------------
#  Description: Deploy/Redeploy Laravel application pods with latest image
# ==========================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="laravel-app"
DEPLOYMENTS=("laravel-http" "laravel-scheduler" "laravel-horizon")
TIMEOUT="300s"

# Functions
print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  Laravel Application Deployment${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo -e "Namespace: ${GREEN}$NAMESPACE${NC}"
    echo -e "Deployments: ${GREEN}${DEPLOYMENTS[*]}${NC}"
    echo ""
}

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -n, --namespace NAMESPACE    Kubernetes namespace [default: laravel-app]"
    echo "  -t, --timeout TIMEOUT       Rollout timeout [default: 300s]"
    echo "  -s, --status                 Check deployment status only"
    echo "  -h, --help                   Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                          # Deploy all Laravel pods"
    echo "  $0 -s                       # Check deployment status"
    echo "  $0 -n my-namespace          # Deploy to custom namespace"
    echo "  $0 -t 600s                  # Deploy with custom timeout"
}

check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
        exit 1
    fi
    
    # Test kubectl connectivity
    if ! kubectl cluster-info &>/dev/null; then
        echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
        echo -e "${YELLOW}Make sure you're authenticated and have access to the cluster${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ kubectl connectivity verified${NC}"
}

check_namespace() {
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        echo -e "${RED}Error: Namespace '$NAMESPACE' does not exist${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Namespace '$NAMESPACE' exists${NC}"
}

show_current_status() {
    echo -e "${YELLOW}Current Pod Status:${NC}"
    kubectl get pods -n "$NAMESPACE" -l "app in (laravel-http,laravel-scheduler,laravel-horizon)" -o wide
    echo ""
    
    echo -e "${YELLOW}Deployment Status:${NC}"
    for deployment in "${DEPLOYMENTS[@]}"; do
        if kubectl get deployment "$deployment" -n "$NAMESPACE" &>/dev/null; then
            echo -e "${CYAN}$deployment:${NC}"
            kubectl get deployment "$deployment" -n "$NAMESPACE" -o custom-columns="READY:.status.readyReplicas,UP-TO-DATE:.status.updatedReplicas,AVAILABLE:.status.availableReplicas,AGE:.metadata.creationTimestamp"
        else
            echo -e "${RED}$deployment: Not found${NC}"
        fi
    done
    echo ""
}

restart_deployments() {
    echo -e "${YELLOW}Restarting Laravel deployments...${NC}"
    
    # Restart all deployments
    local restart_cmd="kubectl rollout restart deployment"
    for deployment in "${DEPLOYMENTS[@]}"; do
        if kubectl get deployment "$deployment" -n "$NAMESPACE" &>/dev/null; then
            restart_cmd="$restart_cmd $deployment"
        else
            echo -e "${YELLOW}Warning: Deployment '$deployment' not found, skipping${NC}"
        fi
    done
    restart_cmd="$restart_cmd -n $NAMESPACE"
    
    echo -e "${CYAN}Running: $restart_cmd${NC}"
    eval "$restart_cmd"
    echo ""
}

wait_for_rollout() {
    echo -e "${YELLOW}Waiting for rollouts to complete...${NC}"
    
    for deployment in "${DEPLOYMENTS[@]}"; do
        if kubectl get deployment "$deployment" -n "$NAMESPACE" &>/dev/null; then
            echo -e "${CYAN}Waiting for $deployment rollout...${NC}"
            if kubectl rollout status deployment "$deployment" -n "$NAMESPACE" --timeout="$TIMEOUT"; then
                echo -e "${GREEN}✓ $deployment rollout completed${NC}"
            else
                echo -e "${RED}✗ $deployment rollout failed or timed out${NC}"
                return 1
            fi
        fi
    done
    echo ""
}

verify_deployment() {
    echo -e "${YELLOW}Verifying new deployment...${NC}"
    
    # Get new pod names
    local new_pods=$(kubectl get pods -n "$NAMESPACE" -l "app in (laravel-http,laravel-scheduler,laravel-horizon)" --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[*].metadata.name}')
    
    echo -e "${CYAN}New pods:${NC}"
    for pod in $new_pods; do
        local age=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.startTime}')
        local status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
        echo -e "  ${GREEN}$pod${NC} - Status: $status"
    done
    echo ""
    
    # Check image versions
    echo -e "${CYAN}Image versions:${NC}"
    local http_pod=$(kubectl get pods -n "$NAMESPACE" -l app=laravel-http -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$http_pod" ]; then
        local image=$(kubectl get pod "$http_pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].image}')
        echo -e "  Image: ${GREEN}$image${NC}"
        
        # Check GCS configuration
        echo -e "${CYAN}GCS Configuration:${NC}"
        kubectl exec "$http_pod" -n "$NAMESPACE" -- env | grep -E "GOOGLE_CLOUD|GCS" | head -3 || echo -e "  ${YELLOW}GCS env vars not found${NC}"
    fi
    echo ""
}

run_health_check() {
    echo -e "${YELLOW}Running health checks...${NC}"
    
    local http_pod=$(kubectl get pods -n "$NAMESPACE" -l app=laravel-http -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$http_pod" ]; then
        echo -e "${CYAN}Testing Laravel application...${NC}"
        if kubectl exec "$http_pod" -n "$NAMESPACE" -- php artisan --version &>/dev/null; then
            local version=$(kubectl exec "$http_pod" -n "$NAMESPACE" -- php artisan --version 2>/dev/null)
            echo -e "  ${GREEN}✓ Laravel is running: $version${NC}"
        else
            echo -e "  ${RED}✗ Laravel health check failed${NC}"
            return 1
        fi
        
        # Test GCS connectivity
        echo -e "${CYAN}Testing GCS connectivity...${NC}"
        if kubectl exec "$http_pod" -n "$NAMESPACE" -- php -r "echo 'GCS Test: '; try { \$client = new Google\Cloud\Storage\StorageClient(['projectId' => getenv('GOOGLE_CLOUD_PROJECT_ID')]); echo 'SUCCESS'; } catch (Exception \$e) { echo 'FAILED: ' . \$e->getMessage(); }" 2>/dev/null | grep -q "SUCCESS"; then
            echo -e "  ${GREEN}✓ GCS connectivity working${NC}"
        else
            echo -e "  ${YELLOW}⚠ GCS connectivity test inconclusive${NC}"
        fi
    else
        echo -e "  ${YELLOW}No HTTP pod found for health check${NC}"
    fi
    echo ""
}

# Parse command line arguments
STATUS_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -s|--status)
            STATUS_ONLY=true
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

# Main execution
print_header
check_kubectl
check_namespace

if [ "$STATUS_ONLY" = true ]; then
    show_current_status
    exit 0
fi

echo -e "${YELLOW}Starting Laravel application deployment...${NC}"
echo ""

# Show current status
show_current_status

# Confirm deployment
read -p "$(echo -e ${CYAN}Continue with deployment? [y/N]: ${NC})" -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 0
fi
echo ""

# Execute deployment
restart_deployments
wait_for_rollout
verify_deployment
run_health_check

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Laravel Deployment Completed Successfully!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo -e "• Test your application endpoints"
echo -e "• Monitor pod logs: ${YELLOW}kubectl logs -f deployment/laravel-http -n $NAMESPACE${NC}"
echo -e "• Check pod status: ${YELLOW}kubectl get pods -n $NAMESPACE${NC}"
echo ""
