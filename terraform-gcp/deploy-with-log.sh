#!/bin/bash

# Wrapper script that uses deploy.sh and logs all output
# This leverages the existing, tested deploy.sh script

set -e

# Configuration
PROJECT_ID="zyoshu"
ENVIRONMENT="staging"
LOG_FILE="deployment-log.md"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Starting Deployment with Logging ===${NC}"
echo -e "Using existing deploy.sh script"
echo -e "Logging to: $LOG_FILE\n"

# Initialize log file
cat > "$LOG_FILE" << EOF
# Deployment Log for Zyoshu Laravel GKE Infrastructure

## Project Details
- **Project ID**: $PROJECT_ID
- **Region**: asia-northeast1 (Tokyo, Japan)
- **Environment**: $ENVIRONMENT
- **Domain**: zyoshu-test.com
- **Date**: $TIMESTAMP
- **Method**: Using deploy.sh script

## Deployment Execution

### Full Deployment Command
\`\`\`bash
./deploy.sh -p $PROJECT_ID -e $ENVIRONMENT -a apply -y
\`\`\`

### Deployment Output
\`\`\`
EOF

# Run deploy.sh and capture all output
echo -e "${YELLOW}Executing: ./deploy.sh -p $PROJECT_ID -e $ENVIRONMENT -a apply -y${NC}"

# Create a temporary file for capturing output
TEMP_LOG=$(mktemp)

# Run the deployment and capture output
if ./deploy.sh -p "$PROJECT_ID" -e "$ENVIRONMENT" -a apply -y 2>&1 | tee "$TEMP_LOG"; then
    DEPLOY_STATUS="✅ Success"
    echo -e "\n${GREEN}Deployment completed successfully!${NC}"
else
    DEPLOY_STATUS="❌ Failed"
    echo -e "\n${RED}Deployment failed!${NC}"
fi

# Append output to log file
cat "$TEMP_LOG" >> "$LOG_FILE"
echo "\`\`\`" >> "$LOG_FILE"

# Add status and summary
cat >> "$LOG_FILE" << EOF

## Deployment Status: $DEPLOY_STATUS

### Post-Deployment Information
EOF

# If deployment succeeded, get outputs
if [[ "$DEPLOY_STATUS" == "✅ Success" ]]; then
    cd environment/$ENVIRONMENT/gke
    
    # Get outputs
    echo -e "\n${YELLOW}Retrieving deployment outputs...${NC}"
    
    cat >> "../../../$LOG_FILE" << EOF

#### Infrastructure Outputs
- **Cluster Name**: $(terraform output -raw cluster_name 2>/dev/null || echo "Not available")
- **Ingress IP**: $(terraform output -raw ingress_ip 2>/dev/null || echo "Not available")
- **Redis Internal IP**: $(terraform output -raw redis_internal_ip 2>/dev/null || echo "Not available")

#### Database Information
EOF
    
    cd ../cloud-sql
    cat >> "../../../$LOG_FILE" << EOF
- **Database Host**: $(terraform output -raw database_host 2>/dev/null || echo "Not available")
- **Database Name**: $(terraform output -raw database_name 2>/dev/null || echo "Not available")
- **Database User**: $(terraform output -raw database_user 2>/dev/null || echo "Not available")

#### Access Commands
\`\`\`bash
# Configure kubectl
$(cd ../gke && terraform output -raw kubectl_config_command 2>/dev/null || echo "Not available")

# Check pods
kubectl get pods -n laravel-app

# Get ingress
kubectl get ingress -n laravel-app
\`\`\`

#### Next Steps
1. Configure Cloudflare DNS:
   - Point \`zyoshu-test.com\` to the Ingress IP
   - Point \`*.zyoshu-test.com\` to the Ingress IP
2. Set SSL mode in Cloudflare to "Flexible" or "Full"
3. Test the application at https://zyoshu-test.com
EOF
    
    cd ../../..
fi

# Clean up temp file
rm -f "$TEMP_LOG"

echo -e "\n${GREEN}Log saved to: $LOG_FILE${NC}"
echo -e "View the log: cat $LOG_FILE"
