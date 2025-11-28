#!/bin/bash

# ==========================================================================
#  Manual GCS Setup for Laravel Multi-Tenant Application
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
PROJECT_ID="zyoshu-test"
ENVIRONMENT="staging"
REGION="us-central1"
ZONE="us-central1-a"
CLUSTER_NAME="laravel-cluster-stg"
NAMESPACE="laravel-app"

# Service Account Names
GCS_SA_NAME="laravel-gcs-stg"
GCS_SA_EMAIL="${GCS_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
K8S_SA_NAME="laravel"

# Bucket Names
SHARED_BUCKET="${PROJECT_ID}-laravel-shared-stg"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Manual GCS Setup for Laravel${NC}"
echo -e "${BLUE}============================================${NC}"
echo -e "Project ID: ${GREEN}$PROJECT_ID${NC}"
echo -e "Environment: ${GREEN}$ENVIRONMENT${NC}"
echo -e "Cluster: ${GREEN}$CLUSTER_NAME${NC}"
echo ""

# Step 1: Authenticate (you need to run this interactively)
echo -e "${YELLOW}Step 1: Authentication${NC}"
echo -e "${CYAN}Run these commands first:${NC}"
echo "gcloud auth login"
echo "gcloud auth application-default login"
echo "gcloud config set project $PROJECT_ID"
echo ""

# Step 2: Enable APIs
echo -e "${YELLOW}Step 2: Enable Required APIs${NC}"
echo "gcloud services enable container.googleapis.com"
echo "gcloud services enable storage.googleapis.com"
echo "gcloud services enable iam.googleapis.com"
echo ""

# Step 3: Create GCS Service Account
echo -e "${YELLOW}Step 3: Create GCS Service Account${NC}"
echo "gcloud iam service-accounts create $GCS_SA_NAME \\"
echo "  --display-name='Laravel GCS Service Account' \\"
echo "  --description='Service account for Laravel application to access Google Cloud Storage'"
echo ""

# Step 4: Assign IAM Roles
echo -e "${YELLOW}Step 4: Assign IAM Roles${NC}"
echo "# Storage Admin role for full GCS access (includes bucket creation)"
echo "gcloud projects add-iam-policy-binding $PROJECT_ID \\"
echo "  --member='serviceAccount:$GCS_SA_EMAIL' \\"
echo "  --role='roles/storage.admin'"
echo ""
echo "# Service usage consumer"
echo "gcloud projects add-iam-policy-binding $PROJECT_ID \\"
echo "  --member='serviceAccount:$GCS_SA_EMAIL' \\"
echo "  --role='roles/serviceusage.serviceUsageConsumer'"
echo ""

# Step 5: Create Shared Bucket
echo -e "${YELLOW}Step 5: Create Shared Bucket${NC}"
echo "gsutil mb -p $PROJECT_ID -c STANDARD -l US gs://$SHARED_BUCKET"
echo ""
echo "# Set bucket lifecycle (optional)"
echo "cat > bucket-lifecycle.json << EOF"
echo "{"
echo "  \"lifecycle\": {"
echo "    \"rule\": ["
echo "      {"
echo "        \"action\": {\"type\": \"Delete\"},"
echo "        \"condition\": {\"age\": 30}"
echo "      }"
echo "    ]"
echo "  }"
echo "}"
echo "EOF"
echo ""
echo "gsutil lifecycle set bucket-lifecycle.json gs://$SHARED_BUCKET"
echo ""

# Step 6: Configure GKE Cluster (if not exists)
echo -e "${YELLOW}Step 6: Get GKE Cluster Credentials${NC}"
echo "gcloud container clusters get-credentials $CLUSTER_NAME \\"
echo "  --zone=$ZONE \\"
echo "  --project=$PROJECT_ID"
echo ""

# Step 7: Create Kubernetes Namespace
echo -e "${YELLOW}Step 7: Create Kubernetes Resources${NC}"
echo "kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -"
echo ""

# Step 8: Create Kubernetes Service Account with Workload Identity
echo -e "${YELLOW}Step 8: Create Kubernetes Service Account${NC}"
echo "cat > k8s-service-account.yaml << EOF"
echo "apiVersion: v1"
echo "kind: ServiceAccount"
echo "metadata:"
echo "  name: $K8S_SA_NAME"
echo "  namespace: $NAMESPACE"
echo "  annotations:"
echo "    iam.gke.io/gcp-service-account: $GCS_SA_EMAIL"
echo "  labels:"
echo "    app: laravel"
echo "    environment: $ENVIRONMENT"
echo "EOF"
echo ""
echo "kubectl apply -f k8s-service-account.yaml"
echo ""

# Step 9: Set up Workload Identity binding
echo -e "${YELLOW}Step 9: Set up Workload Identity Binding${NC}"
echo "gcloud iam service-accounts add-iam-policy-binding $GCS_SA_EMAIL \\"
echo "  --role='roles/iam.workloadIdentityUser' \\"
echo "  --member='serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/${K8S_SA_NAME}]'"
echo ""

# Step 10: Create ConfigMap with GCS Configuration
echo -e "${YELLOW}Step 10: Create ConfigMap with GCS Configuration${NC}"
echo "cat > gcs-config.yaml << EOF"
echo "apiVersion: v1"
echo "kind: ConfigMap"
echo "metadata:"
echo "  name: gcs-config"
echo "  namespace: $NAMESPACE"
echo "data:"
echo "  GOOGLE_CLOUD_PROJECT_ID: '$PROJECT_ID'"
echo "  GOOGLE_CLOUD_STORAGE_BUCKET: '$SHARED_BUCKET'"
echo "  GCS_BUCKET_PREFIX: 'tenant'"
echo "  GCS_BUCKET_LOCATION: 'US'"
echo "  GCS_STORAGE_CLASS: 'STANDARD'"
echo "  GOOGLE_CLOUD_STORAGE_PATH_PREFIX: ''"
echo "  GOOGLE_CLOUD_STORAGE_API_URI: ''"
echo "  GOOGLE_CLOUD_STORAGE_API_ENDPOINT: ''"
echo "EOF"
echo ""
echo "kubectl apply -f gcs-config.yaml"
echo ""

# Step 11: Test the setup
echo -e "${YELLOW}Step 11: Test the Setup${NC}"
echo "# Create a test pod to verify GCS access"
echo "cat > test-gcs-pod.yaml << EOF"
echo "apiVersion: v1"
echo "kind: Pod"
echo "metadata:"
echo "  name: gcs-test"
echo "  namespace: $NAMESPACE"
echo "spec:"
echo "  serviceAccountName: $K8S_SA_NAME"
echo "  containers:"
echo "  - name: gcs-test"
echo "    image: google/cloud-sdk:alpine"
echo "    command: ['/bin/sh']"
echo "    args: ['-c', 'sleep 3600']"
echo "    envFrom:"
echo "    - configMapRef:"
echo "        name: gcs-config"
echo "  restartPolicy: Never"
echo "EOF"
echo ""
echo "kubectl apply -f test-gcs-pod.yaml"
echo ""
echo "# Wait for pod to be ready and test"
echo "kubectl wait --for=condition=Ready pod/gcs-test -n $NAMESPACE --timeout=60s"
echo ""
echo "# Test GCS access"
echo "kubectl exec gcs-test -n $NAMESPACE -- gsutil ls gs://$SHARED_BUCKET"
echo ""
echo "# Test bucket creation"
echo "kubectl exec gcs-test -n $NAMESPACE -- gsutil mb gs://${PROJECT_ID}-test-tenant-bucket || echo 'Bucket creation test completed'"
echo ""
echo "# Clean up test resources"
echo "kubectl delete pod gcs-test -n $NAMESPACE"
echo "gsutil rb gs://${PROJECT_ID}-test-tenant-bucket 2>/dev/null || echo 'Test bucket cleanup completed'"
echo ""

# Step 12: Verification commands
echo -e "${YELLOW}Step 12: Verification Commands${NC}"
echo "# Verify service account"
echo "gcloud iam service-accounts describe $GCS_SA_EMAIL"
echo ""
echo "# Verify IAM bindings"
echo "gcloud projects get-iam-policy $PROJECT_ID \\"
echo "  --flatten='bindings[].members' \\"
echo "  --filter='bindings.members:serviceAccount:$GCS_SA_EMAIL'"
echo ""
echo "# Verify Workload Identity binding"
echo "gcloud iam service-accounts get-iam-policy $GCS_SA_EMAIL"
echo ""
echo "# Verify Kubernetes resources"
echo "kubectl get serviceaccount $K8S_SA_NAME -n $NAMESPACE -o yaml"
echo "kubectl get configmap gcs-config -n $NAMESPACE -o yaml"
echo ""
echo "# List buckets"
echo "gsutil ls -p $PROJECT_ID"
echo ""

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Setup Commands Generated Successfully!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${CYAN}To execute all commands at once, run:${NC}"
echo -e "${YELLOW}bash manual-gcs-setup.sh | bash${NC}"
echo ""
echo -e "${CYAN}Or copy and paste each section manually.${NC}"
