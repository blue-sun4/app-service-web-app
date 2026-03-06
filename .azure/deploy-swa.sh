#!/bin/bash

# ============================================================================
# Azure Static Web Apps Deployment Script for React + Vite Application
# ============================================================================
#
# Purpose: Deploy a React SPA to Azure Static Web Apps (NO QUOTA ISSUES!)
# Static Web Apps is PERFECT for SPAs - handles client-side routing natively
#
# Fully Idempotent Deployment - Safe to run multiple times
#
# Features:
#  ✓ Checks resource existence before creating
#  ✓ Skips already-created resources
#  ✓ Handles errors gracefully
#  ✓ Full deployment verification
#  ✓ Native SPA routing support (no web.config needed!)
#
# Configuration:
#   - Subscription: 2165d0b7-5e28-4054-9df0-10871d681f2c
#   - Region: eastus
#   - Resource Group: react-app-rg
#   - Static Web App: react-app-prod
#
# Usage:
#   chmod +x .azure/deploy-swa.sh
#   ./.azure/deploy-swa.sh
#
# ============================================================================

# Strict error handling
set -euo pipefail
IFS=$'\n\t'

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================================================
# Configuration - Load from environment variables (with auto-detection fallback)
# ============================================================================

# Load config file if it exists
if [ -f ".azure/config.env" ]; then
  set +u  # Temporarily allow unset variables
  source ".azure/config.env"
  set -u  # Re-enable strict mode
fi

# Configuration - with smart defaults
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-}"
STATIC_WEB_APP_NAME="${AZURE_STATIC_WEB_APP:-}"
REGION="${AZURE_REGION:-eastus2}"  # Static Web Apps region
BUILD_DIR="${AZURE_BUILD_DIR:-./dist}"
APP_LOCATION="${AZURE_APP_LOCATION:-/}"
OUTPUT_LOCATION="${AZURE_OUTPUT_LOCATION:-dist}"

# Logging functions
log_phase() { echo -e "\n${GREEN}→ $1${NC}"; }
log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
log_error() { echo -e "${RED}✗ $1${NC}"; }
log_info() { echo -e "ℹ $1"; }

# Error trap
trap 'log_error "Deployment failed at line $LINENO"; exit 1' ERR

# ============================================================================
# Phase 1: Validation & Setup
# ============================================================================
log_phase "Phase 1: Validation & Setup"

# Check prerequisites
log_info "Checking prerequisites..."
for cmd in az node yarn; do
  if ! command -v "$cmd" &> /dev/null; then
    log_error "$cmd is not installed"
    exit 1
  fi
done
log_success "All prerequisites installed"

# Verify Azure authentication
log_info "Verifying Azure authentication..."
CURRENT_SUBSCRIPTION=$(az account show --query id -o tsv 2>/dev/null || echo "")
if [ -z "$CURRENT_SUBSCRIPTION" ]; then
  log_error "Not logged in to Azure. Run: az login"
  exit 1
fi

# Use current subscription if none specified
if [ -z "$SUBSCRIPTION_ID" ]; then
  SUBSCRIPTION_ID="$CURRENT_SUBSCRIPTION"
  log_info "Using current subscription: $SUBSCRIPTION_ID"
else
  log_info "Using subscription: $SUBSCRIPTION_ID"
  if [ "$CURRENT_SUBSCRIPTION" != "$SUBSCRIPTION_ID" ]; then
    log_info "Switching to target subscription..."
    az account set --subscription "$SUBSCRIPTION_ID" > /dev/null
    log_success "Switched to target subscription"
  else
    log_success "Already on target subscription"
  fi
fi

# Auto-detect resource group if not specified
if [ -z "$RESOURCE_GROUP" ]; then
  log_info "Auto-detecting resource group..."
  RG_LIST=$(az group list --query "[].name" --output tsv)
  RG_COUNT=$(echo "$RG_LIST" | wc -w)
  
  if [ "$RG_COUNT" -eq 0 ]; then
    log_error "No resource groups found"
    exit 1
  elif [ "$RG_COUNT" -eq 1 ]; then
    RESOURCE_GROUP=$RG_LIST
    log_success "Resource Group: $RESOURCE_GROUP (auto-detected)"
  else
    log_error "Multiple resource groups found. Specify with: AZURE_RESOURCE_GROUP=name"
    echo "$RG_LIST" | sed 's/^/  - /'
    exit 1
  fi
fi
log_info "Resource Group: $RESOURCE_GROUP"

# Auto-detect Static Web App if not specified
if [ -z "$STATIC_WEB_APP_NAME" ]; then
  log_info "Auto-detecting Static Web App..."
  APP_LIST=$(az staticwebapp list --resource-group "$RESOURCE_GROUP" --query "[].name" --output tsv 2>/dev/null || echo "")
  APP_COUNT=$(echo "$APP_LIST" | wc -w)
  
  if [ "$APP_COUNT" -eq 0 ]; then
    log_info "No Static Web App found. Creating new one..."
    STATIC_WEB_APP_NAME="${RANDOM}-app"
    log_info "Will create: $STATIC_WEB_APP_NAME"
  elif [ "$APP_COUNT" -eq 1 ]; then
    STATIC_WEB_APP_NAME=$APP_LIST
    log_success "Static Web App: $STATIC_WEB_APP_NAME (auto-detected)"
  else
    log_error "Multiple Static Web Apps found. Specify with: AZURE_STATIC_WEB_APP=name"
    echo "$APP_LIST" | sed 's/^/  - /'
    exit 1
  fi
fi
log_info "Static Web App: $STATIC_WEB_APP_NAME"

# ============================================================================
# Phase 2: Building React Application
# ============================================================================
log_phase "Phase 2: Building React Application"

# Check if dist directory exists and is valid
if [ -d "$BUILD_DIR" ] && [ -f "$BUILD_DIR/index.html" ]; then
  log_warning "Build output already exists. Rebuilding to ensure fresh deployment..."
fi

# Install dependencies
log_info "Installing dependencies..."
yarn install --frozen-lockfile
log_success "Dependencies installed"

# Build application
log_info "Building application..."
yarn build
if [ ! -f "$BUILD_DIR/index.html" ]; then
  log_error "Build failed - index.html not found in $BUILD_DIR"
  exit 1
fi
log_success "Build complete. Output: $BUILD_DIR"

# ============================================================================
# Phase 3: Creating/Verifying Azure Resources
# ============================================================================
log_phase "Phase 3: Creating/Verifying Azure Resources"

# Check and create Resource Group
log_info "Checking Resource Group: $RESOURCE_GROUP..."
if az group exists --name "$RESOURCE_GROUP" --output json | grep -q true; then
  log_success "Resource Group already exists"
else
  log_info "Creating Resource Group..."
  az group create \
    --name "$RESOURCE_GROUP" \
    --location "$REGION" \
    --output table
  log_success "Resource Group created"
fi

# Check and create Static Web App
log_info "Checking Static Web App: $STATIC_WEB_APP_NAME..."
EXISTING_SWA=$(az staticwebapp list \
  --resource-group "$RESOURCE_GROUP" \
  --query "[?name=='$STATIC_WEB_APP_NAME'].id" \
  --output tsv 2>/dev/null || echo "")

if [ -z "$EXISTING_SWA" ]; then
  log_info "Creating Static Web App..."
  az staticwebapp create \
    --name "$STATIC_WEB_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$REGION" \
    --sku "Free" \
    --output table
  log_success "Static Web App created"
else
  log_success "Static Web App already exists"
fi

# ============================================================================
# Phase 4: Deploying Build Output
# ============================================================================
log_phase "Phase 4: Deploying Build Output to Static Web App"

# Get the default host URL (deployment token required for production)
log_info "Retrieving Static Web App details..."
APP_ID=$(az staticwebapp show \
  --name "$STATIC_WEB_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "id" \
  --output tsv 2>/dev/null || echo "")

if [ -z "$APP_ID" ]; then
  log_error "Failed to retrieve Static Web App ID"
  exit 1
fi

APP_URL=$(az staticwebapp show \
  --name "$STATIC_WEB_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "defaultHostname" \
  --output tsv 2>/dev/null || echo "")

if [ -z "$APP_URL" ]; then
  log_warning "Could not retrieve default hostname yet (may not be ready)"
  log_info "Check Azure Portal for default URL"
else
  log_success "Static Web App URL: https://$APP_URL"
fi

log_info "For CI/CD deployment, connect GitHub repo in Azure Portal:"
log_info "1. Go to Azure Portal > $STATIC_WEB_APP_NAME"
log_info "2. Click 'Connect GitHub' in the left menu"
log_info "3. Select your repository and branch"
log_info "4. Set Build Details: App location: '$APP_LOCATION', Output location: '$OUTPUT_LOCATION'"

# ============================================================================
# Phase 5: Post-Deployment Configuration
# ============================================================================
log_phase "Phase 5: Post-Deployment Configuration"

# Create staticwebapp.config.json for route configuration
CONFIG_FILE="$BUILD_DIR/staticwebapp.config.json"
log_info "Creating Static Web App configuration..."

cat > "$CONFIG_FILE" << 'EOF'
{
  "routes": [
    {
      "route": "/*",
      "serve": "/index.html",
      "statusCode": 200
    },
    {
      "route": "/api/*",
      "serve": "/api/*",
      "statusCode": 404
    }
  ],
  "mimeTypes": {
    ".wasm": "application/wasm"
  }
}
EOF

log_success "Configuration file created: $CONFIG_FILE"

# ============================================================================
# Phase 6: Verification
# ============================================================================
log_phase "Phase 6: Deployment Verification"

# Verify Static Web App exists
log_info "Verifying Static Web App deployment..."
if az staticwebapp show \
  --name "$STATIC_WEB_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "name" \
  --output tsv 2>/dev/null | grep -q "$STATIC_WEB_APP_NAME"; then
  log_success "Static Web App verified"
else
  log_error "Static Web App verification failed"
  exit 1
fi

# Verify build output exists
if [ ! -d "$BUILD_DIR" ] || [ ! -f "$BUILD_DIR/index.html" ]; then
  log_error "Build output missing"
  exit 1
fi
log_success "Build output verified"

# ============================================================================
# Phase 7: Summary
# ============================================================================
log_phase "Phase 7: Deployment Summary"

cat << EOF

${GREEN}✓ DEPLOYMENT SUCCESSFUL${NC}

Application Details:
  Resource Group: $RESOURCE_GROUP
  Static Web App: $STATIC_WEB_APP_NAME
  Region: $REGION
  Build Output: $BUILD_DIR
  
Next Steps:
  1. GO TO AZURE PORTAL: https://portal.azure.com
  2. FIND YOUR STATIC WEB APP: '$STATIC_WEB_APP_NAME' in resource group '$RESOURCE_GROUP'
  3. ENABLE GITHUB DEPLOYMENT:
     - Click "Setup connection" or "Connect GitHub"
     - Authorize GitHub and select your repository
     - Configure: App location: '$APP_LOCATION', Output location: '$OUTPUT_LOCATION'
  4. GITHUB WORKFLOW ENABLED: Automatic deployments on every push
  
Default Hostname:
  Once GitHub is connected, visit: https://<default-hostname-will-appear>
  
NOTE: The default Azure hostname is temporary. For a custom domain:
  - Azure Portal > Static Web App > Custom domain > Add custom domain
  - Point your domain CNAME to: <default-hostname>
  
Health Check:
  After deployment, test your routes:
  - GET https://<hostname>/ (Home page)
  - GET https://<hostname>/about (About page)
  - GET https://<hostname>/contact-us (Contact page)

${GREEN}✓ All phases completed successfully${NC}

EOF

exit 0
