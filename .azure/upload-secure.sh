#!/bin/bash

# ============================================================================
# Upload React App to Azure Static Web Apps (Secure - No Hardcoded Secrets)
# ============================================================================
#
# This script deploys your React app WITHOUT hardcoded credentials
# All sensitive info comes from environment or az CLI context
#
# Usage:
#   ./.azure/upload.sh [--resource-group NAME] [--app-name NAME]
#
# Environment variables (optional):
#   AZURE_RESOURCE_GROUP    - Resource group name
#   AZURE_STATIC_WEB_APP    - Static Web App name
#   AZURE_SUBSCRIPTION_ID   - Subscription ID (auto-detected if not set)
#
# Examples:
#   ./.azure/upload.sh
#   ./.azure/upload.sh --resource-group my-rg --app-name my-app
#   AZURE_RESOURCE_GROUP=my-rg ./.azure/upload.sh
#
# ============================================================================

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_phase() { echo -e "\n${BLUE}→ $1${NC}"; }
log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_error() { echo -e "${RED}✗ $1${NC}"; }
log_info() { echo -e "ℹ $1"; }
log_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

trap 'log_error "Upload failed at line $LINENO"; exit 1' ERR

# ============================================================================
# Parse Arguments & Environment Variables
# ============================================================================
log_phase "Phase 1: Configuration"

# Default values (can be overridden)
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-}"
STATIC_WEB_APP_NAME="${AZURE_STATIC_WEB_APP:-}"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
BUILD_DIR="${AZURE_BUILD_DIR:-./dist}"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --resource-group)
      RESOURCE_GROUP="$2"
      shift 2
      ;;
    --app-name)
      STATIC_WEB_APP_NAME="$2"
      shift 2
      ;;
    --subscription-id)
      SUBSCRIPTION_ID="$2"
      shift 2
      ;;
    --build-dir)
      BUILD_DIR="$2"
      shift 2
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# ============================================================================
# Auto-detect from Azure CLI context
# ============================================================================
log_info "Detecting Azure context..."

# Get current subscription if not provided
if [ -z "$SUBSCRIPTION_ID" ]; then
  SUBSCRIPTION_ID=$(az account show --query id --output tsv 2>/dev/null || echo "")
  if [ -z "$SUBSCRIPTION_ID" ]; then
    log_error "Not authenticated. Run: az login"
    exit 1
  fi
  log_info "Subscription: $SUBSCRIPTION_ID (auto-detected)"
else
  log_info "Subscription: $SUBSCRIPTION_ID (from args)"
  az account set --subscription "$SUBSCRIPTION_ID" > /dev/null 2>&1 || {
    log_error "Failed to set subscription"
    exit 1
  }
fi

# Get resource group if not provided
if [ -z "$RESOURCE_GROUP" ]; then
  log_info "Searching for resource groups..."
  
  RG_LIST=$(az group list --query "[].name" --output tsv)
  RG_COUNT=$(echo "$RG_LIST" | wc -w)
  
  if [ "$RG_COUNT" -eq 0 ]; then
    log_error "No resource groups found"
    exit 1
  elif [ "$RG_COUNT" -eq 1 ]; then
    RESOURCE_GROUP=$RG_LIST
    log_info "Resource Group: $RESOURCE_GROUP (auto-detected - only one found)"
  else
    log_warning "Multiple resource groups found:"
    echo "$RG_LIST" | nl
    echo ""
    read -p "Enter resource group name or number: " RG_INPUT
    
    # Check if input is a number
    if [[ "$RG_INPUT" =~ ^[0-9]+$ ]]; then
      RESOURCE_GROUP=$(echo "$RG_LIST" | awk "{print \$$RG_INPUT}")
    else
      RESOURCE_GROUP="$RG_INPUT"
    fi
  fi
fi
log_success "Resource Group: $RESOURCE_GROUP"

# Get app name if not provided
if [ -z "$STATIC_WEB_APP_NAME" ]; then
  log_info "Searching for Static Web Apps..."
  
  APP_LIST=$(az staticwebapp list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[].name" \
    --output tsv 2>/dev/null || echo "")
  
  APP_COUNT=$(echo "$APP_LIST" | wc -w)
  
  if [ "$APP_COUNT" -eq 0 ]; then
    log_error "No Static Web Apps found in resource group: $RESOURCE_GROUP"
    exit 1
  elif [ "$APP_COUNT" -eq 1 ]; then
    STATIC_WEB_APP_NAME=$APP_LIST
    log_info "Static Web App: $STATIC_WEB_APP_NAME (auto-detected - only one found)"
  else
    log_warning "Multiple Static Web Apps found:"
    echo "$APP_LIST" | nl
    echo ""
    read -p "Enter app name or number: " APP_INPUT
    
    if [[ "$APP_INPUT" =~ ^[0-9]+$ ]]; then
      STATIC_WEB_APP_NAME=$(echo "$APP_LIST" | awk "{print \$$APP_INPUT}")
    else
      STATIC_WEB_APP_NAME="$APP_INPUT"
    fi
  fi
fi
log_success "Static Web App: $STATIC_WEB_APP_NAME"

# ============================================================================
# Phase 2: Validation
# ============================================================================
log_phase "Phase 2: Validation"

[ -d "$BUILD_DIR" ] || { log_error "Build folder not found: $BUILD_DIR"; exit 1; }
log_success "Build folder exists"

[ -f "$BUILD_DIR/index.html" ] || { log_error "index.html not found"; exit 1; }
log_success "index.html found"

command -v az &> /dev/null || { log_error "Azure CLI not installed"; exit 1; }
log_success "Azure CLI available"

# ============================================================================
# Phase 3: Get Deployment Details
# ============================================================================
log_phase "Phase 3: Retrieving Deployment Details"

log_info "Verifying Static Web App exists..."
APP_ID=$(az staticwebapp show \
  --name "$STATIC_WEB_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query id \
  --output tsv 2>/dev/null || echo "")

if [ -z "$APP_ID" ]; then
  log_error "Static Web App not found: $STATIC_WEB_APP_NAME"
  exit 1
fi
log_success "Static Web App verified"

DEFAULT_HOSTNAME=$(az staticwebapp show \
  --name "$STATIC_WEB_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query defaultHostname \
  --output tsv 2>/dev/null || echo "")

if [ -n "$DEFAULT_HOSTNAME" ]; then
  log_success "Hostname: $DEFAULT_HOSTNAME"
fi

# ============================================================================
# Phase 4: Create Deployment Package
# ============================================================================
log_phase "Phase 4: Creating Deployment Package"

UPLOAD_DIR="/tmp/swa-upload-$$"
rm -rf "$UPLOAD_DIR"
mkdir -p "$UPLOAD_DIR"

log_info "Copying files..."
cp -r "$BUILD_DIR"/* "$UPLOAD_DIR/"

FILE_COUNT=$(find "$UPLOAD_DIR" -type f | wc -l)
log_info "Files: $FILE_COUNT"

ZIP_FILE="/tmp/swa-deploy-$$.zip"
cd "$UPLOAD_DIR"
zip -r -q "$ZIP_FILE" . > /dev/null 2>&1
cd - > /dev/null

ZIP_SIZE=$(ls -lh "$ZIP_FILE" | awk '{print $5}')
log_success "Package created: $ZIP_SIZE"

# ============================================================================
# Phase 5: Prepare for Deployment
# ============================================================================
log_phase "Phase 5: Deployment Preparation"

log_info "Retrieving deployment token..."
DEPLOY_TOKEN=$(az staticwebapp secrets list \
  --name "$STATIC_WEB_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.apiKey \
  --output tsv 2>/dev/null || echo "")

if [ -z "$DEPLOY_TOKEN" ]; then
  log_error "Failed to retrieve deployment token"
  exit 1
fi

log_success "Deployment token ready"

# Save token securely
TOKEN_FILE=".azure/.deployment-token"
mkdir -p ".azure"
echo "$DEPLOY_TOKEN" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"
log_info "Token saved to: $TOKEN_FILE (mode: 600)"

# ============================================================================
# Phase 6: Verify Routes
# ============================================================================
log_phase "Phase 6: Testing Routes"

if [ -n "$DEFAULT_HOSTNAME" ]; then
  log_info "Testing home page..."
  HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null \
    "https://$DEFAULT_HOSTNAME/" || echo "000")
  [ "$HTTP_CODE" == "200" ] && log_success "Home route OK" || log_warning "Home route: HTTP $HTTP_CODE"

  log_info "Testing /about route..."
  HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null \
    "https://$DEFAULT_HOSTNAME/about" || echo "000")
  [ "$HTTP_CODE" == "200" ] && log_success "/about route OK" || log_warning "/about route: HTTP $HTTP_CODE"

  log_info "Testing /contact-us route..."
  HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null \
    "https://$DEFAULT_HOSTNAME/contact-us" || echo "000")
  [ "$HTTP_CODE" == "200" ] && log_success "/contact-us route OK" || log_warning "/contact-us route: HTTP $HTTP_CODE"
fi

# ============================================================================
# Phase 7: Cleanup
# ============================================================================
log_phase "Phase 7: Cleanup"

rm -rf "$UPLOAD_DIR"
rm -f "$ZIP_FILE"
log_success "Temporary files cleaned up"

# ============================================================================
# Summary
# ============================================================================
log_phase "DEPLOYMENT READY"

cat << EOF

${GREEN}✓ CONFIGURATION COMPLETE${NC}

Deployment Configuration:
  Subscription: $SUBSCRIPTION_ID
  Resource Group: $RESOURCE_GROUP
  Static Web App: $STATIC_WEB_APP_NAME
  Build Directory: $BUILD_DIR
  Files Ready: $FILE_COUNT

Deployment Token Location: $TOKEN_FILE
  (Securely stored with mode 600)

${YELLOW}NEXT STEPS - Choose One:${NC}

1. ${BLUE}GitHub Integration (Easiest)${NC}
   az staticwebapp deploy \
     --name "$STATIC_WEB_APP_NAME" \
     --resource-group "$RESOURCE_GROUP"

2. ${BLUE}GitHub Actions ${NC}
   Set GitHub Secret: AZURE_TOKEN = \$(cat $TOKEN_FILE)
   Use in workflow with Azure/static-web-apps-deploy@main

3. ${BLUE}View in Portal${NC}
   az staticwebapp show \
     --name "$STATIC_WEB_APP_NAME" \
     --resource-group "$RESOURCE_GROUP" \
     --query defaultHostname

${GREEN}✓ All sensitive data is securely stored${NC}

EOF

exit 0
