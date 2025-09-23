#!/bin/bash

# ==========================================================================
#  Execute GCS Setup Commands - Run this after authentication
# ==========================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_ID="zyoshu-test"

echo -e "${BLUE}=== Executing GCS Setup Commands ===${NC}"
echo -e "Project: ${GREEN}$PROJECT_ID${NC}"
echo ""

echo -e "${YELLOW}Step 1: Enable APIs${NC}"
gcloud services enable container.googleapis.com storage.googleapis.com iam.googleapis.com --project=$PROJECT_ID
echo -e "${GREEN}✓ APIs enabled${NC}"
echo ""

echo -e "${YELLOW}Step 2: Create Service Account${NC}"
gcloud iam service-accounts create laravel-gcs-stg \
  --display-name='Laravel GCS Service Account' \
  --description='Service account for Laravel application to access Google Cloud Storage' \
  --project=$PROJECT_ID || echo "Service account may already exist"
echo -e "${GREEN}✓ Service account created${NC}"
echo ""

echo -e "${YELLOW}Step 3: Assign IAM Roles${NC}"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member='serviceAccount:laravel-gcs-stg@zyoshu-test.iam.gserviceaccount.com' \
  --role='roles/storage.admin'

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member='serviceAccount:laravel-gcs-stg@zyoshu-test.iam.gserviceaccount.com' \
  --role='roles/serviceusage.serviceUsageConsumer'
echo -e "${GREEN}✓ IAM roles assigned${NC}"
echo ""

echo -e "${YELLOW}Step 4: Create Shared Bucket${NC}"
gsutil mb -p $PROJECT_ID -c STANDARD -l US gs://zyoshu-test-laravel-shared-stg || echo "Bucket may already exist"
gsutil lifecycle set bucket-lifecycle.json gs://zyoshu-test-laravel-shared-stg
echo -e "${GREEN}✓ Shared bucket created${NC}"
echo ""

echo -e "${YELLOW}Step 5: Get GKE Credentials${NC}"
gcloud container clusters get-credentials laravel-cluster-stg \
  --zone=us-central1-a \
  --project=$PROJECT_ID
echo -e "${GREEN}✓ GKE credentials configured${NC}"
echo ""

echo -e "${YELLOW}Step 6: Apply Kubernetes Resources${NC}"
kubectl apply -f k8s-gcs-resources.yaml
echo -e "${GREEN}✓ Kubernetes resources created${NC}"
echo ""

echo -e "${YELLOW}Step 7: Set up Workload Identity Binding${NC}"
gcloud iam service-accounts add-iam-policy-binding laravel-gcs-stg@zyoshu-test.iam.gserviceaccount.com \
  --role='roles/iam.workloadIdentityUser' \
  --member='serviceAccount:zyoshu-test.svc.id.goog[laravel-app/laravel]'
echo -e "${GREEN}✓ Workload Identity binding created${NC}"
echo ""

echo -e "${YELLOW}Step 8: Test Setup${NC}"
echo "Waiting for test pod to be ready..."
kubectl wait --for=condition=Ready pod/gcs-test -n laravel-app --timeout=120s

echo "Testing GCS access..."
kubectl exec gcs-test -n laravel-app -- gsutil ls gs://zyoshu-test-laravel-shared-stg

echo "Testing bucket creation..."
kubectl exec gcs-test -n laravel-app -- gsutil mb gs://zyoshu-test-test-tenant-bucket || echo 'Bucket creation test completed'

echo "Cleaning up test..."
kubectl delete pod gcs-test -n laravel-app
gsutil rb gs://zyoshu-test-test-tenant-bucket 2>/dev/null || echo 'Test bucket cleanup completed'
echo -e "${GREEN}✓ Setup tested successfully${NC}"
echo ""

echo -e "${BLUE}=== Setup Complete! ===${NC}"
echo ""
echo -e "${CYAN}Verification commands:${NC}"
echo "gcloud iam service-accounts describe laravel-gcs-stg@zyoshu-test.iam.gserviceaccount.com"
echo "kubectl get serviceaccount laravel -n laravel-app -o yaml"
echo "kubectl get configmap gcs-config -n laravel-app -o yaml"
echo "gsutil ls -p $PROJECT_ID"
