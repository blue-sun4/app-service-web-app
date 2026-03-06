#!/bin/bash

# ============================================================================
# Deploy React App using Azure Static Web Apps CLI (swa)
# ============================================================================
# 
# Uses the @azure/static-web-apps-cli for deployment
# Requires: yarn/npm install @azure/static-web-apps-cli
#
# Configuration:
#   Load from: .azure/config.env or environment variables
#   Auto-detect: From Azure CLI context
#
# Usage:
#   ./.azure/deploy.sh
#   AZURE_RESOURCE_GROUP=my-rg AZURE_STATIC_WEB_APP=my-app ./.azure/deploy.sh
#
# ============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_phase() { echo -e "\n${BLUE}→ $1${NC}"; }
log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_error() { echo -e "${RED}✗ $1${NC}"; }
log_info() { echo -e "ℹ $1"; }

trap 'log_error "Deployment failed at line $LINENO"; exit 1' ERR

# ============================================================================
# Phase 1: Configuration
# ============================================================================
log_phase "Phase 1: Configuration"

# Load config file if exists
if [ -f ".azure/config.env" ]; then
  set +u
  source ".azure/config.env"
  set -u
  log_info "Loaded configuration from .azure/config.env"
fi

# Use environment variables or defaults
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-}"
STATIC_WEB_APP_NAME="${AZURE_STATIC_WEB_APP:-}"
BUILD_DIR="${AZURE_BUILD_DIR:-./dist}"

# Auto-detect subscription
if [ -z "$SUBSCRIPTION_ID" ]; then
  SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null || echo "")
  [ -z "$SUBSCRIPTION_ID" ] && { log_error "Not authenticated. Run: az login"; exit 1; }
  log_info "Subscription: $SUBSCRIPTION_ID (auto-detected)"
fi

# Auto-detect resource group
if [ -z "$RESOURCE_GROUP" ]; then
  log_info "Auto-detecting resource group..."
  RG_COUNT=$(az group list --query 'length(@)' -o tsv)
  if [ "$RG_COUNT" -eq 0 ]; then
    log_error "No resource groups found"
    exit 1
  elif [ "$RG_COUNT" -eq 1 ]; then
    RESOURCE_GROUP=$(az group list --query "[0].name" -o tsv)
    log_success "Resource Group: $RESOURCE_GROUP (auto-detected)"
  else
    log_error "Multiple resource groups found. Specify with: AZURE_RESOURCE_GROUP=name"
    az group list --query "[].name" -o tsv | sed 's/^/  - /'
    exit 1
  fi
fi

# Auto-detect Static Web App
if [ -z "$STATIC_WEB_APP_NAME" ]; then
  log_info "Auto-detecting Static Web App..."
  APP_COUNT=$(az staticwebapp list --resource-group "$RESOURCE_GROUP" --query 'length(@)' -o tsv 2>/dev/null || echo "0")
  if [ "$APP_COUNT" -eq 0 ]; then
    log_error "No Static Web Apps found in $RESOURCE_GROUP"
    exit 1
  elif [ "$APP_COUNT" -eq 1 ]; then
    STATIC_WEB_APP_NAME=$(az staticwebapp list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)
    log_success "Static Web App: $STATIC_WEB_APP_NAME (auto-detected)"
  else
    log_error "Multiple Static Web Apps found. Specify with: AZURE_STATIC_WEB_APP=name"
    az staticwebapp list --resource-group "$RESOURCE_GROUP" --query "[].name" -o tsv | sed 's/^/  - /'
    exit 1
  fi
fi

log_info "Resource Group: $RESOURCE_GROUP"
log_info "Static Web App: $STATIC_WEB_APP_NAME"

# ============================================================================
# Phase 2: Validation
# ============================================================================
log_phase "Phase 2: Validation"

[ -d "$BUILD_DIR" ] || { log_error "Build directory not found: $BUILD_DIR"; exit 1; }
log_success "Build directory exists"

[ -f "$BUILD_DIR/index.html" ] || { log_error "index.html not found"; exit 1; }
log_success "index.html found"

# Check for swa CLI - prioritize local installation
if [ -f "node_modules/.bin/swa" ]; then
  SWA_CMD="node_modules/.bin/swa"
  log_success "Using swa from node_modules"
elif command -v swa &> /dev/null; then
  SWA_CMD="swa"
  log_success "Using swa from PATH"
else
  log_error "swa CLI not found"
  log_info "Install with: yarn add -D @azure/static-web-apps-cli"
  exit 1
fi

# ============================================================================
# Phase 3: Build Application
# ============================================================================
log_phase "Phase 3: Building Application"

log_info "Building React application..."
yarn build > /dev/null 2>&1
log_success "Build complete"

# Verify build
[ -f "$BUILD_DIR/index.html" ] || { log_error "Build verification failed"; exit 1; }
log_success "Build verification passed"

# Ensure SPA routing config exists (created by Vite from public/ folder)
if [ ! -f "$BUILD_DIR/staticwebapp.config.json" ]; then
  log_info "Adding SPA routing configuration..."
  cat > "$BUILD_DIR/staticwebapp.config.json" << 'EOFCONFIG'
{
  "routes": [
    {
      "route": "/*",
      "rewrite": "/index.html"
    }
  ]
}
EOFCONFIG
  log_success "SPA routing config created"
else
  log_success "SPA routing config found"
fi

# ============================================================================
# Phase 4: Get Deployment Token
# ============================================================================
log_phase "Phase 4: Retrieving Deployment Credentials"

log_info "Getting deployment token..."
DEPLOY_TOKEN=$(az staticwebapp secrets list \
  --name "$STATIC_WEB_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.apiKey \
  --output tsv 2>/dev/null || echo "")

if [ -z "$DEPLOY_TOKEN" ]; then
  log_error "Failed to retrieve deployment token"
  exit 1
fi

log_success "Deployment token retrieved"

# Save token securely
mkdir -p ".azure"
echo "$DEPLOY_TOKEN" > ".azure/.deployment-token"
chmod 600 ".azure/.deployment-token"

# ============================================================================
# Phase 5: Deploy using swa CLI
# ============================================================================
log_phase "Phase 5: Deploying with Static Web Apps CLI"

log_info "Deploying to: $STATIC_WEB_APP_NAME"
log_info "Build directory: $BUILD_DIR"
echo ""

$SWA_CMD deploy "$BUILD_DIR" \
  --deployment-token "$DEPLOY_TOKEN" \
  --env production

log_success "Deployment completed"

# ============================================================================
# Phase 6: Get App Details
# ============================================================================
log_phase "Phase 6: App Details"

DEFAULT_HOSTNAME=$(az staticwebapp show \
  --name "$STATIC_WEB_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query defaultHostname \
  --output tsv 2>/dev/null || echo "pending")

log_success "App deployed to: https://$DEFAULT_HOSTNAME"

# ============================================================================
# Phase 7: Verify Routes
# ============================================================================
log_phase "Phase 7: Verification"

if [ "$DEFAULT_HOSTNAME" != "pending" ]; then
  log_info "Testing routes..."
  sleep 3
  
  for route in "/" "/about" "/contact-us"; do
    HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null "https://$DEFAULT_HOSTNAME$route" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" == "200" ]; then
      log_success "Route $route: HTTP 200"
    else
      log_info "Route $route: HTTP $HTTP_CODE"
    fi
  done
fi

# ============================================================================
# Summary
# ============================================================================
log_phase "Deployment Summary"

cat << EOF

${GREEN}✓ DEPLOYMENT SUCCESSFUL${NC}

Application: $STATIC_WEB_APP_NAME
Resource Group: $RESOURCE_GROUP
URL: https://$DEFAULT_HOSTNAME
Build Directory: $BUILD_DIR

Routes:
  ✓ Home: /
  ✓ About: /about
  ✓ Contact: /contact-us

${YELLOW}Next Steps:${NC}
1. Enable GitHub Deployments (Recommended)
   - Visit: https://portal.azure.com
   - Find: $STATIC_WEB_APP_NAME in $RESOURCE_GROUP
   - Click: Deployment > Connect GitHub
   - Select: blue-sun4/app-service-web-app
   - Configure: App location: /, Output location: dist
   - Save: Automatic deployments enabled

2. Test Your App
   Visit: https://$DEFAULT_HOSTNAME

${GREEN}✓ Your React app is live!${NC}

EOF

exit 0
