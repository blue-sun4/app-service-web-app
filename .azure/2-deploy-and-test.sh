#!/bin/bash

# ============================================================================
# Deploy React App and Run Tests
# ============================================================================
#
# Builds, deploys to Azure, and verifies the deployment
# Uses configuration from setup script
#
# Features:
#  ✓ Builds React app with clean dist
#  ✓ Validates build output
#  ✓ Deploys to Azure Static Web Apps using swa CLI
#  ✓ Verifies all routes with proper error checking
#  ✓ Tests app accessibility
#  ✓ Secure handling of deployment credentials
#  ✓ Optional: Push to Git (excludes dist/)
#  ✓ Supports CI/CD environments
#
# Prerequisites:
#  - Run .azure/1-setup-azure.sh first
#  - Azure CLI 2.40+
#  - Node.js 18+
#  - yarn or npm
#  - @azure/static-web-apps-cli 1.0+
#
# Usage (Standard):
#   chmod +x .azure/2-deploy-and-test.sh
#   ./.azure/2-deploy-and-test.sh
#
# Usage (Options):
#   ./.azure/2-deploy-and-test.sh --skip-tests          # Skip route verification
#   ./.azure/2-deploy-and-test.sh --skip-build          # Use existing dist/
#   ./.azure/2-deploy-and-test.sh --with-git            # Commit and push to Git
#   ./.azure/2-deploy-and-test.sh --skip-tests --skip-build
#
# CI/CD Environment Variables:
#   CI=true                                      # Runs in non-interactive mode
#   DEBUG=1                                      # Enables debug logging
#
# ============================================================================

set -euo pipefail

# Enable debug mode if DEBUG env var is set
if [[ "${DEBUG:-0}" == "1" ]]; then
  set -x
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log_phase() { echo -e "\n${BLUE}→ Phase: $1${NC}"; }
log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_error() { echo -e "${RED}✗ $1${NC}"; }
log_info() { echo -e "ℹ $1"; }
log_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
log_debug() { [ "${DEBUG:-0}" == "1" ] && echo -e "${BLUE}[DEBUG] $1${NC}" || true; }

trap 'log_error "Deployment failed at line $LINENO"; exit 1' ERR

# Cleanup on interrupt
trap 'log_error "Deployment interrupted"; exit 130' INT TERM

# Parse arguments
SKIP_TESTS=false
SKIP_BUILD=false
WITH_GIT=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-tests)
      SKIP_TESTS=true
      log_debug "Tests skipped"
      shift
      ;;
    --skip-build)
      SKIP_BUILD=true
      log_debug "Build skipped"
      shift
      ;;
    --with-git)
      WITH_GIT=true
      log_debug "Git integration enabled"
      shift
      ;;
    *)
      log_error "Unknown option: $1"
      echo "Valid options: --skip-tests, --skip-build, --with-git"
      exit 1
      ;;
  esac
done

# ============================================================================
# Phase 1: Configuration
# ============================================================================
log_phase "Loading Configuration"

CONFIG_FILE=".azure/config.env"
if [ ! -f "$CONFIG_FILE" ]; then
  log_error "Configuration not found: $CONFIG_FILE"
  log_error "Run setup first: ./.azure/1-setup-azure.sh"
  exit 1
fi

set +u
source "$CONFIG_FILE"
set -u

# Validate configuration
for var in AZURE_SUBSCRIPTION_ID AZURE_RESOURCE_GROUP AZURE_STATIC_WEB_APP; do
  if [ -z "${!var:-}" ]; then
    log_error "Missing configuration: $var"
    exit 1
  fi
  log_debug "$var=${!var}"
done

log_success "Configuration loaded"
log_info "Subscription: $AZURE_SUBSCRIPTION_ID"
log_info "Resource Group: $AZURE_RESOURCE_GROUP"
log_info "Static Web App: $AZURE_STATIC_WEB_APP"

# ============================================================================
# Phase 2: Prerequisites
# ============================================================================
log_phase "Checking Prerequisites"

# Check Azure CLI
if ! command -v az &> /dev/null; then
  log_error "Azure CLI not installed"
  exit 1
fi
AZ_VERSION=$(az version --query '["azure-cli"]' -o tsv 2>/dev/null || echo "unknown")
log_debug "Azure CLI version: $AZ_VERSION"
log_success "Azure CLI installed"

# Check Node.js
if ! command -v node &> /dev/null; then
  log_error "Node.js not installed"
  exit 1
fi
NODE_VERSION=$(node --version 2>/dev/null || echo "unknown")
log_debug "Node.js version: $NODE_VERSION"
log_success "Node.js installed"

# Check package manager (yarn or npm)
PKG_MANAGER=""
if command -v yarn &> /dev/null; then
  PKG_MANAGER="yarn"
  log_success "yarn installed"
elif command -v npm &> /dev/null; then
  PKG_MANAGER="npm"
  log_success "npm installed"
else
  log_error "Neither yarn nor npm is installed"
  exit 1
fi

# Check swa CLI
if [ ! -f "node_modules/.bin/swa" ]; then
  log_warning "swa CLI not found, installing..."
  if [ "$PKG_MANAGER" == "yarn" ]; then
    yarn add -D @azure/static-web-apps-cli > /dev/null 2>&1 || {
      log_error "Failed to install @azure/static-web-apps-cli"
      exit 1
    }
  else
    npm install --save-dev @azure/static-web-apps-cli > /dev/null 2>&1 || {
      log_error "Failed to install @azure/static-web-apps-cli"
      exit 1
    }
  fi
fi
log_success "swa CLI available"

# Verify Azure auth
if ! az account show &> /dev/null; then
  log_error "Not logged into Azure. Run: az login"
  exit 1
fi
log_success "Authenticated to Azure"

# ============================================================================
# Phase 3: Build Application
# ============================================================================
if [ "$SKIP_BUILD" = true ]; then
  log_phase "Application Build (Skipped)"
  
  if [ ! -f "dist/index.html" ]; then
    log_error "dist/index.html not found (--skip-build requires existing build)"
    exit 1
  fi
  log_success "Using existing build"
else
  log_phase "Building Application"
  
  # Clean previous build
  log_info "Cleaning dist directory..."
  if [ -d "dist" ]; then
    rm -rf dist
    log_debug "dist/ removed"
  fi
  
  # Build with package manager
  log_info "Building React application..."
  if [ "$PKG_MANAGER" == "yarn" ]; then
    yarn build 2>&1 | grep -v "^yarn run" | tail -20 || {
      log_error "Build failed"
      exit 1
    }
  else
    npm run build 2>&1 | tail -20 || {
      log_error "Build failed"
      exit 1
    }
  fi
  
  log_success "Build complete"
  
  # Verify build output
  if [ ! -f "dist/index.html" ]; then
    log_error "Build failed - index.html not found in dist/"
    exit 1
  fi
  
  # Check build size
  BUILD_SIZE=$(du -sh dist/ 2>/dev/null | cut -f1 || echo "unknown")
  log_success "Build verified (size: $BUILD_SIZE)"
fi

# ============================================================================
# Phase 4: Deploy to Azure
# ============================================================================
log_phase "Deploying to Azure"

# Set subscription
log_info "Configuring subscription..."
az account set --subscription "$AZURE_SUBSCRIPTION_ID" > /dev/null 2>&1 || {
  log_error "Failed to set subscription"
  exit 1
}
log_success "Subscription configured"

# Get deployment token (securely)
log_info "Retrieving deployment credentials..."
DEPLOY_TOKEN=$(az staticwebapp secrets list \
  --name "$AZURE_STATIC_WEB_APP" \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --query properties.apiKey \
  --output tsv 2>/dev/null || echo "")

if [ -z "$DEPLOY_TOKEN" ]; then
  log_error "Could not retrieve deployment token"
  log_info "Ensure the Static Web App is fully created and try again"
  exit 1
fi
log_debug "Deployment token retrieved (length: ${#DEPLOY_TOKEN})"
log_success "Deployment credentials retrieved"

# Deploy using swa CLI (token not logged)
log_info "Uploading application to Azure..."
if ! node_modules/.bin/swa deploy \
  ./dist \
  --deployment-token "$DEPLOY_TOKEN" \
  --env production > /dev/null 2>&1; then
  log_error "Deployment failed. Check Azure credentials and app name"
  exit 1
fi

log_success "Deployment successful"

# Get app URL
APP_URL=$(az staticwebapp show \
  --name "$AZURE_STATIC_WEB_APP" \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --query defaultHostname \
  --output tsv 2>/dev/null || echo "")

if [ -n "$APP_URL" ]; then
  log_success "App deployed to: https://$APP_URL"
  log_debug "Full URL: https://$APP_URL"
else
  log_warning "Could not retrieve app URL"
fi

# ============================================================================
# Phase 5: Verify Deployment
# ============================================================================
if [ "$SKIP_TESTS" = false ]; then
  log_phase "Testing Deployment"
  
  if [ -z "$APP_URL" ]; then
    log_warning "Skipping deployment tests (no app URL available)"
  else
    # Wait for deployment to propagate
    log_info "Waiting for deployment to propagate..."
    sleep 3
    
    # Test main route
    log_info "Testing application routes..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$APP_URL/" 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "200" ]; then
      log_success "Root route (HTTP $HTTP_CODE)"
    elif [ "$HTTP_CODE" = "404" ]; then
      log_warning "Root route returned 404 - check routing configuration"
    else
      log_warning "Root route returned HTTP $HTTP_CODE"
    fi
    
    # Test additional routes if they exist
    declare -a ROUTES=("/about" "/contact-us")
    declare -a ROUTE_NAMES=("About" "Contact")
    
    for i in "${!ROUTES[@]}"; do
      ROUTE="${ROUTES[$i]}"
      NAME="${ROUTE_NAMES[$i]}"
      
      HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$APP_URL$ROUTE" 2>/dev/null || echo "000")
      
      if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "304" ]; then
        log_success "Route $NAME ($ROUTE): HTTP $HTTP_CODE"
      elif [ "$HTTP_CODE" = "404" ]; then
        log_info "Route $NAME ($ROUTE): Not found - verify SPA routing"
      else
        log_warning "Route $NAME ($ROUTE): HTTP $HTTP_CODE"
      fi
    done
    
    log_success "Deployment verification complete"
  fi
else
  log_phase "Testing Skipped"
  log_info "Route verification skipped (--skip-tests)"
fi

# ============================================================================
# Phase 6: Git Integration (Optional)
# ============================================================================
if [ "$WITH_GIT" = true ]; then
  log_phase "Git Integration"
  
  # Check if git repo exists
  if [ ! -d ".git" ]; then
    log_warning "Not a git repository"
    IS_INTERACTIVE="${CI:-}" && IS_INTERACTIVE="false" || IS_INTERACTIVE="true"
    
    if [ "$IS_INTERACTIVE" == "true" ]; then
      read -p "Initialize git? (y/n) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        git init > /dev/null
        log_success "Git repository initialized"
      fi
    else
      log_info "Skipping git init (non-interactive mode)"
    fi
  fi
  
  # Ensure proper .gitignore entries
  if [ -f ".gitignore" ]; then
    if ! grep -q "^dist/$" .gitignore; then
      echo "dist/" >> .gitignore
      log_debug "Added dist/ to .gitignore"
    fi
    if ! grep -q "^node_modules/$" .gitignore; then
      echo "node_modules/" >> .gitignore
      log_debug "Added node_modules/ to .gitignore"
    fi
    if ! grep -q "^\.azure/config\.env$" .gitignore; then
      echo ".azure/config.env" >> .gitignore
      log_debug "Added .azure/config.env to .gitignore"
    fi
  fi
  
  # Check for changes
  if ! git diff-index --quiet HEAD --; then
    log_info "Staging changes..."
    
    # Use git add with ignore of dist/ and node_modules
    git add -A -- ':!dist/' ':!node_modules/' > /dev/null 2>&1 || git add -A > /dev/null 2>&1
    
    # Prepare commit message
    IS_INTERACTIVE="${CI:-}" && IS_INTERACTIVE="false" || IS_INTERACTIVE="true"
    if [ "$IS_INTERACTIVE" == "true" ]; then
      read -p "Enter commit message (default: 'Deploy application'): " COMMIT_MSG || true
    else
      COMMIT_MSG=""
    fi
    
    COMMIT_MSG="${COMMIT_MSG:-Deploy application}"
    
    # Commit changes
    log_info "Committing changes..."
    if git commit -m "$COMMIT_MSG" > /dev/null 2>&1; then
      log_success "Changes committed: $COMMIT_MSG"
    else
      log_warning "Nothing to commit or commit failed"
    fi
  else
    log_info "No changes to commit"
  fi
  
  # Push if remote exists
  if git remote get-url origin &>/dev/null; then
    log_info "Pushing to remote..."
    if git push origin HEAD > /dev/null 2>&1; then
      log_success "Pushed to remote repository"
      BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
      log_debug "Branch: $BRANCH"
    else
      log_warning "Push failed - verify remote configuration"
    fi
  else
    log_info "No remote configured (run: git remote add origin <url>)"
  fi
else
  log_phase "Git Integration"
  log_info "Git integration skipped"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "Deployment Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -n "$APP_URL" ]; then
  echo "🚀 Your app is live!"
  echo ""
  echo "Visit your application:"
  echo "  → https://$APP_URL"
  echo ""
fi

echo "📋 Available Commands:"
echo "  Redeploy:       ./.azure/2-deploy-and-test.sh"
echo "  Skip tests:     ./.azure/2-deploy-and-test.sh --skip-tests"
echo "  Skip build:     ./.azure/2-deploy-and-test.sh --skip-build"
echo "  With Git push:  ./.azure/2-deploy-and-test.sh --with-git"
echo ""

if [ -n "$APP_URL" ]; then
  echo "📊 Monitoring:"
  echo "  View logs:      az staticwebapp logs"
  echo "                  --name $AZURE_STATIC_WEB_APP"
  echo "                  --resource-group $AZURE_RESOURCE_GROUP"
  echo ""
  echo "  Settings:       https://portal.azure.com"
  echo ""
fi

echo "💡 Best Practices:"
echo "  • Keep .azure/config.env out of version control"
echo "  • Test locally before deploying"
echo "  • Review logs regularly for errors"
if [ "$WITH_GIT" = true ]; then
  echo "  • dist/ and node_modules/ are git-ignored"
fi
echo ""
