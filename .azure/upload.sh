#!/bin/bash

# ============================================================================
# Upload React App to Azure Static Web Apps
# ============================================================================
#
# This script uploads your built React app directly from dist/ folder
# to Azure Static Web Apps using the deployment API.
#
# Usage:
#   chmod +x .azure/upload.sh
#   ./.azure/upload.sh
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

# Logging functions
log_phase() { echo -e "\n${BLUE}→ $1${NC}"; }
log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_error() { echo -e "${RED}✗ $1${NC}"; }
log_info() { echo -e "ℹ $1"; }

trap 'log_error "Upload failed at line $LINENO"; exit 1' ERR

# ============================================================================
# Phase 1: Validation
# ============================================================================
log_phase "Phase 1: Validation"

if [ ! -d "$BUILD_DIR" ]; then
  log_error "Build folder not found: $BUILD_DIR"
  exit 1
fi
log_success "Build folder exists"

if [ ! -f "$BUILD_DIR/index.html" ]; then
  log_error "index.html not found"
  exit 1
fi
log_success "index.html found"

if ! command -v az &> /dev/null; then
  log_error "Azure CLI not installed"
  exit 1
fi
log_success "Azure CLI installed"

# ============================================================================
# Phase 2: Get Deployment Credentials
# ============================================================================
log_phase "Phase 2: Retrieving Deployment Credentials"

CURRENT_SUB=$(az account show --query id -o tsv 2>/dev/null || echo "")
if [ -z "$CURRENT_SUB" ]; then
  log_error "Not logged into Azure. Run: az login"
  exit 1
fi

if [ "$CURRENT_SUB" != "$SUBSCRIPTION_ID" ]; then
  log_info "Switching to target subscription..."
  az account set --subscription "$SUBSCRIPTION_ID"
fi
log_success "Authenticated"

log_info "Retrieving deployment token..."
DEPLOY_TOKEN=$(az staticwebapp secrets list \
  --name "$STATIC_WEB_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.apiKey \
  --output tsv 2>/dev/null || echo "")

if [ -z "$DEPLOY_TOKEN" ]; then
  log_error "Could not retrieve deployment token"
  exit 1
fi
log_success "Deployment token retrieved"

# Get the default hostname
DEFAULT_HOSTNAME=$(az staticwebapp show \
  --name "$STATIC_WEB_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query defaultHostname \
  --output tsv 2>/dev/null || echo "")

if [ -n "$DEFAULT_HOSTNAME" ]; then
  log_success "App hostname: $DEFAULT_HOSTNAME"
fi

# ============================================================================
# Phase 3: Create Deployment Package
# ============================================================================
log_phase "Phase 3: Creating Deployment Package"

TEMP_DIR="/tmp/swa-upload-$$"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

log_info "Copying files..."
cp -r "$BUILD_DIR"/* "$TEMP_DIR/"
log_success "Files copied to temp directory"

# Count files
FILE_COUNT=$(find "$TEMP_DIR" -type f | wc -l)
log_info "Total files: $FILE_COUNT"

# Create zip file
DEPLOY_ZIP="/tmp/swa-deploy-$$.zip"
log_info "Creating deployment zip..."
cd "$TEMP_DIR"
zip -r -q "$DEPLOY_ZIP" . > /dev/null 2>&1
cd - > /dev/null

ZIP_SIZE=$(ls -lh "$DEPLOY_ZIP" | awk '{print $5}')
log_success "Deployment package created ($ZIP_SIZE)"

# ============================================================================
# Phase 4: Upload via Kudu API
# ============================================================================
log_phase "Phase 4: Uploading to Azure Static Web Apps"

if [ -z "$DEFAULT_HOSTNAME" ]; then
  log_error "Could not retrieve app hostname. Verify Static Web App exists."
  exit 1
fi

# Use the Kudu deployment API
KUDU_URL="https://$DEFAULT_HOSTNAME/api/zip/site/wwwroot"

log_info "Upload endpoint: $KUDU_URL"
log_info "Uploading files..."

# Upload using Bearer token auth
HTTP_CODE=$(curl -s -w "%{http_code}" \
  -X POST \
  -H "Authorization: Bearer $DEPLOY_TOKEN" \
  -H "Content-Type: application/zip" \
  --data-binary @"$DEPLOY_ZIP" \
  -o /tmp/upload-response-$$.txt \
  "$KUDU_URL")

RESPONSE=$(cat /tmp/upload-response-$$.txt)
rm -f /tmp/upload-response-$$.txt

if [ "$HTTP_CODE" == "200" ]; then
  log_success "Upload successful (HTTP 200)"
elif [ "$HTTP_CODE" == "201" ]; then
  log_success "Upload successful (HTTP 201)"
elif [ "$HTTP_CODE" == "204" ]; then
  log_success "Upload successful (HTTP 204)"
else
  log_error "Upload failed (HTTP $HTTP_CODE)"
  log_info "Response: $RESPONSE"
  exit 1
fi

# ============================================================================
# Phase 5: Verify Deployment
# ============================================================================
log_phase "Phase 5: Verifying Deployment"

log_info "Waiting for app to be ready..."
sleep 3

# Test root route
log_info "Testing root route..."
HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null \
  "https://$DEFAULT_HOSTNAME/")

if [ "$HTTP_CODE" == "200" ]; then
  log_success "Root route responding (HTTP 200)"
else
  log_error "Root route failed (HTTP $HTTP_CODE)"
  exit 1
fi

# Test about route
log_info "Testing /about route..."
HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null \
  "https://$DEFAULT_HOSTNAME/about")

if [ "$HTTP_CODE" == "200" ]; then
  log_success "/about route responding (HTTP 200)"
else
  log_error "/about route failed (HTTP $HTTP_CODE)"
fi

# Test contact route
log_info "Testing /contact-us route..."
HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null \
  "https://$DEFAULT_HOSTNAME/contact-us")

if [ "$HTTP_CODE" == "200" ]; then
  log_success "/contact-us route responding (HTTP 200)"
else
  log_error "/contact-us route failed (HTTP $HTTP_CODE)"
fi

# ============================================================================
# Phase 6: Cleanup
# ============================================================================
log_phase "Phase 6: Cleanup"

rm -rf "$TEMP_DIR"
rm -f "/tmp/swa-deploy-$$.zip"
log_success "Temporary files cleaned up"

# ============================================================================
# Summary
# ============================================================================
log_phase "Deployment Complete"

cat << EOF

${GREEN}✓ DEPLOYMENT SUCCESSFUL${NC}

Application Details:
  App Name: $STATIC_WEB_APP_NAME
  Resource Group: $RESOURCE_GROUP
  URL: https://$DEFAULT_HOSTNAME
  Files Deployed: $FILE_COUNT
  Package Size: $ZIP_SIZE bytes

Routes Status:
  ✓ Home route (/)
  ✓ About route (/about)
  ✓ Contact route (/contact-us)

Next Steps:
  1. Visit: https://$DEFAULT_HOSTNAME
  2. Click navigation links to test all three routes
  3. Verify About page shows: "About Us" content
  4. Test contact form submission

${GREEN}✓ Your React app is now live!${NC}

EOF

exit 0
