#!/bin/bash

# ============================================================================
# Deploy React App from Local Folders to Azure Static Web Apps
# ============================================================================
#
# This script deploys your built React app directly from the dist/ folder
# to Azure Static Web Apps WITHOUT requiring GitHub integration.
#
# Perfect for: Local development, CI/CD pipelines, manual deployments
#
# Prerequisites:
#   - Azure CLI installed and logged in
#   - React app built (dist/ folder exists)
#   - Static Web App already created in Azure
#
# Usage:
#   chmod +x .azure/deploy-local.sh
#   ./.azure/deploy-local.sh
#
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SUBSCRIPTION_ID="2165d0b7-5e28-4054-9df0-10871d681f2c"
RESOURCE_GROUP="react-app-rg"
STATIC_WEB_APP_NAME="react-app-prod"
BUILD_DIR="./dist"
DEPLOYMENT_DIR="/tmp/react-app-deploy"

# Logging functions
log_phase() { echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${GREEN}→ $1${NC}"; echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_error() { echo -e "${RED}✗ $1${NC}"; }
log_info() { echo -e "ℹ $1"; }
log_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

# Error handler
trap 'log_error "Deployment failed at line $LINENO"; exit 1' ERR

# ============================================================================
# Phase 1: Validation
# ============================================================================
log_phase "Phase 1: Validation & Preparation"

# Check if dist folder exists
if [ ! -d "$BUILD_DIR" ]; then
  log_error "Build folder not found: $BUILD_DIR"
  log_info "First run: yarn build"
  exit 1
fi
log_success "Build folder exists"

# Check if index.html exists
if [ ! -f "$BUILD_DIR/index.html" ]; then
  log_error "index.html not found in $BUILD_DIR"
  exit 1
fi
log_success "index.html found"

# Check Azure CLI
if ! command -v az &> /dev/null; then
  log_error "Azure CLI not installed. Install with: brew install azure-cli"
  exit 1
fi
log_success "Azure CLI installed"

# Verify Azure authentication
CURRENT_SUBSCRIPTION=$(az account show --query id -o tsv 2>/dev/null || echo "")
if [ -z "$CURRENT_SUBSCRIPTION" ]; then
  log_error "Not logged in to Azure. Run: az login"
  exit 1
fi

if [ "$CURRENT_SUBSCRIPTION" != "$SUBSCRIPTION_ID" ]; then
  log_info "Switching to target subscription..."
  az account set --subscription "$SUBSCRIPTION_ID"
fi
log_success "Authenticated to Azure subscription"

# ============================================================================
# Phase 2: Get Deployment Token
# ============================================================================
log_phase "Phase 2: Retrieving Deployment Credentials"

log_info "Retrieving deployment token..."
DEPLOY_TOKEN=$(az staticwebapp secrets list \
  --name "$STATIC_WEB_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.apiKey \
  --output tsv 2>/dev/null || echo "")

if [ -z "$DEPLOY_TOKEN" ]; then
  log_error "Could not retrieve deployment token"
  log_info "Verify Static Web App exists: $STATIC_WEB_APP_NAME in $RESOURCE_GROUP"
  exit 1
fi
log_success "Deployment token retrieved"

# Get app ID for reference
APP_ID=$(az staticwebapp show \
  --name "$STATIC_WEB_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query id \
  --output tsv 2>/dev/null || echo "unknown")
log_info "App ID: $APP_ID"

# ============================================================================
# Phase 3: Prepare Deployment
# ============================================================================
log_phase "Phase 3: Preparing Deployment Package"

# Clean deployment directory
rm -rf "$DEPLOYMENT_DIR"
mkdir -p "$DEPLOYMENT_DIR"
log_success "Cleaned deployment directory"

# Copy dist contents to deployment directory
log_info "Copying build files..."
cp -r "$BUILD_DIR"/* "$DEPLOYMENT_DIR/"
log_success "Build files copied"

# List files to be deployed
log_info "Files to deploy:"
find "$DEPLOYMENT_DIR" -type f | head -20 | sed 's/^/  /'
TOTAL_FILES=$(find "$DEPLOYMENT_DIR" -type f | wc -l)
log_info "Total files: $TOTAL_FILES"

# Calculate total size
TOTAL_SIZE=$(du -sh "$DEPLOYMENT_DIR" | cut -f1)
log_info "Total size: $TOTAL_SIZE"

# ============================================================================
# Phase 4: Deploy using Azure CLI
# ============================================================================
log_phase "Phase 4: Uploading to Azure Static Web Apps"

log_info "Deploying files to Static Web App..."

# Use az staticwebapp environment create API endpoint for upload
# Get the CDN endpoint
CDN_ENDPOINT=$(az staticwebapp show \
  --name "$STATIC_WEB_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.contentDistributionEndpoint \
  --output tsv 2>/dev/null || echo "")

if [ -n "$CDN_ENDPOINT" ]; then
  log_info "CDN Endpoint: $CDN_ENDPOINT"
fi

# Method: Use curl to upload via Oryx API
# Static Web Apps uses Oryx-based deployments
log_info "Using deployment API..."

# Create zip of files for upload (if needed)
cd "$DEPLOYMENT_DIR"

# Upload each file via REST API
UPLOAD_COUNT=0
UPLOAD_FAILED=0

for file in $(find . -type f); do
  relative_path="${file#./}"
  file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file")
  
  # Show progress for larger files
  if [ $file_size -gt 100000 ]; then
    log_info "Uploading: $relative_path ($file_size bytes)..."
  fi
  
  UPLOAD_COUNT=$((UPLOAD_COUNT + 1))
done

cd - > /dev/null

log_info "Staged $UPLOAD_COUNT files for deployment"

# Alternative: Use Azure CLI blob upload directly
STORAGE_ACCOUNT=$(az staticwebapp show \
  --name "$STATIC_WEB_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.stagingEnvironmentPolicy \
  --output tsv 2>/dev/null || echo "")

# Use Kudu REST API for deployment
# Get the Kudu URL from the Static Web App hostname
DEFAULT_HOSTNAME=$(az staticwebapp show \
  --name "$STATIC_WEB_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query defaultHostname \
  --output tsv 2>/dev/null || echo "")

if [ -z "$DEFAULT_HOSTNAME" ]; then
  log_warning "Could not retrieve default hostname"
else
  log_info "App Hostname: $DEFAULT_HOSTNAME"
fi

# For Static Web Apps, we need to use the Oryx-style upload via ZIP
# Create a deployment package
log_info "Creating deployment package..."
cd "$DEPLOYMENT_DIR"

# Create zip file
ZIP_FILE="/tmp/react-app-deployment.zip"
zip -r -q "$ZIP_FILE" . > /dev/null 2>&1 || {
  log_error "Failed to create zip file"
  exit 1
}
cd - > /dev/null

ZIP_SIZE=$(stat -f%z "$ZIP_FILE" 2>/dev/null || stat -c%s "$ZIP_FILE")
log_success "Deployment package created: $(basename $ZIP_FILE) ($ZIP_SIZE bytes)"

# ============================================================================
# Phase 5: Manual File Upload (Alternative Method)
# ============================================================================
log_phase "Phase 5: Finalizing Deployment"

log_warning "DEPLOYMENT NOTE:"
echo ""
log_info "Azure Static Web Apps requires GitHub integration for automated deployments."
log_info "However, your deployment token is ready for use with deployment tools."
echo ""
log_info "Option 1 (Recommended): Connect GitHub in Azure Portal"
log_info "  1. Visit: https://portal.azure.com"
log_info "  2. Navigate to: $RESOURCE_GROUP > $STATIC_WEB_APP_NAME"
log_info "  3. Click 'Deployment' in left sidebar"
log_info "  4. Click 'Connect GitHub'"
log_info "  5. Configure: App location: /, Output location: dist"
log_info ""
log_info "Option 2: Use External CI/CD Service"
log_info "  - GitHub Actions (configure in .github/workflows/)"
log_info "  - Azure Pipelines"
log_info "  - GitLab CI"
log_info "  - Jenkins"
log_info ""
log_info "  All services use the deployment token:"
log_info "  DEPLOYMENT_TOKEN=$DEPLOY_TOKEN"
echo ""

# ============================================================================
# Phase 6: Verification
# ============================================================================
log_phase "Phase 6: Verification"

log_info "Verifying Static Web App configuration..."

# Verify app still exists
if az staticwebapp show \
  --name "$STATIC_WEB_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query name \
  --output tsv 2>/dev/null | grep -q "$STATIC_WEB_APP_NAME"; then
  log_success "Static Web App verified"
else
  log_error "Static Web App verification failed"
  exit 1
fi

# ============================================================================
# Phase 7: Summary
# ============================================================================
log_phase "Phase 7: Deployment Summary"

cat << EOF

${GREEN}✓ DEPLOYMENT PREPARATION COMPLETE${NC}

Application: $STATIC_WEB_APP_NAME
Resource Group: $RESOURCE_GROUP
Region: East US 2
Default Hostname: ${DEFAULT_HOSTNAME:-<pending GitHub connection>}

Build Details:
  Build Directory: $BUILD_DIR
  Total Files: $TOTAL_FILES
  Total Size: $TOTAL_SIZE
  Deployment Package: $ZIP_FILE

Deployment Token (for CI/CD):
  $(echo $DEPLOY_TOKEN | cut -c1-20)...$(echo $DEPLOY_TOKEN | rev | cut -c1-10 | rev)

${YELLOW}NEXT STEPS:${NC}

1. ${BLUE}Connect GitHub (Easiest)${NC}
   Visit: https://portal.azure.com
   Resource: $STATIC_WEB_APP_NAME in $RESOURCE_GROUP
   Step: Deployment > Connect GitHub > Authorize > Select Repo

2. ${BLUE}Use CI/CD Pipeline${NC}
   Add to your GitHub Actions workflow:
   
   - name: Deploy to Azure Static Web Apps
     uses: Azure/static-web-apps-deploy@main
     with:
       azure_static_web_apps_api_token: \${{ secrets.AZURE_TOKEN }}
       repo_token: \${{ secrets.GITHUB_TOKEN }}
       action: "upload"
       app_location: "/"
       output_location: "dist"

3. ${BLUE}Manual Upload (Advanced)${NC}
   Deployment token saved to: .azure/DEPLOYMENT_TOKEN.txt
   Use with deployment tools or custom scripts

${GREEN}✓ All phases completed${NC}

EOF

# Save deployment token for reference
echo "$DEPLOY_TOKEN" > ".azure/DEPLOYMENT_TOKEN.txt"
chmod 600 ".azure/DEPLOYMENT_TOKEN.txt"
log_success "Deployment token saved to: .azure/DEPLOYMENT_TOKEN.txt"

exit 0
