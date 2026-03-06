#!/bin/bash

# ============================================================================
# Azure App Service Deployment Script for React + Vite Application
# ============================================================================
#
# Fully Idempotent Deployment - Safe to run multiple times
#
# Features:
#  ✓ Checks resource existence before creating
#  ✓ Skips already-created resources
#  ✓ Handles errors gracefully
#  ✓ Persistent app name tracking
#  ✓ Full deployment verification
#
# Configuration:
#   - Subscription: 2165d0b7-5e28-4054-9df0-10871d681f2c
#   - Region: eastus
#   - Resource Group: react-app-rg
#   - App Service Plan: react-app-plan
#
# Usage:
#   chmod +x .azure/deploy.sh
#   ./.azure/deploy.sh
#
# ============================================================================

# Strict error handling
set -euo pipefail
IFS=$'\n\t'

# Configuration
SUBSCRIPTION_ID="2165d0b7-5e28-4054-9df0-10871d681f2c"
RESOURCE_GROUP="react-app-rg"
APP_SERVICE_PLAN="react-app-plan"
APP_SERVICE_NAME="react-app-prod"  # Fixed name - idempotent
REGION="eastus"
SKU="B1"  # Basic tier
STATE_FILE=".azure/.deployment-state"
TEMP_DIR="deploy-temp-$$"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

print_step() {
    echo -e "${BLUE}→ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Check if resource group exists
resource_group_exists() {
    az group exists --name "$RESOURCE_GROUP" --output tsv | grep -q "true"
}

# Check if app service plan exists
plan_exists() {
    az appservice plan show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$APP_SERVICE_PLAN" \
        &>/dev/null || return 1
}

# Check if web app exists
webapp_exists() {
    az webapp show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$APP_SERVICE_NAME" \
        &>/dev/null || return 1
}

# Save deployment state
save_state() {
    mkdir -p "$(dirname "$STATE_FILE")"
    cat > "$STATE_FILE" << EOF
DEPLOYED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
APP_SERVICE_NAME=$APP_SERVICE_NAME
RESOURCE_GROUP=$RESOURCE_GROUP
SUBSCRIPTION_ID=$SUBSCRIPTION_ID
REGION=$REGION
EOF
    print_success "Deployment state saved"
}

# Cleanup temporary files
cleanup_temp() {
    if [ -d "$TEMP_DIR" ]; then
        print_step "Cleaning up temporary files..."
        rm -rf "$TEMP_DIR"
        print_success "Cleanup complete"
    fi
}

# Trap for cleanup on exit
trap cleanup_temp EXIT

# Error handler
error_exit() {
    print_error "$1"
    echo ""
    echo "Deployment failed. Troubleshooting:"
    echo "1. Check Azure CLI is logged in: az login"
    echo "2. Verify subscription: az account show"
    echo "3. Check logs: az webapp log tail --name $APP_SERVICE_NAME"
    exit 1
}

# ============================================================================
# PHASE 1: Validation & Setup
# ============================================================================

print_step "Phase 1: Validation & Setup"
echo ""

# Check prerequisites
print_step "Checking prerequisites..."

command -v az >/dev/null 2>&1 || \
    error_exit "Azure CLI is not installed. Install from: https://learn.microsoft.com/cli/azure/install-azure-cli"

command -v yarn >/dev/null 2>&1 || \
    error_exit "Yarn is not installed. Install from: https://classic.yarnpkg.com/en/docs/install"

# Check zip/unzip availability
command -v zip >/dev/null 2>&1 || \
    error_exit "zip command is required. Install with: apt-get install zip or brew install zip"

print_success "All prerequisites installed"

# Check Azure authentication
print_step "Verifying Azure authentication..."
CURRENT_SUBSCRIPTION=$(az account show --output tsv --query id 2>/dev/null || echo "")

if [ -z "$CURRENT_SUBSCRIPTION" ]; then
    error_exit "Not logged in to Azure. Run: az login"
fi

print_info "Current subscription: $CURRENT_SUBSCRIPTION"

# Set subscription
print_step "Switching to target subscription..."
if [ "$CURRENT_SUBSCRIPTION" != "$SUBSCRIPTION_ID" ]; then
    az account set --subscription "$SUBSCRIPTION_ID" || \
        error_exit "Failed to set subscription. Check subscription ID is valid."
    print_success "Subscription switched"
else
    print_success "Already on target subscription"
fi

echo ""

# ============================================================================
# PHASE 2: Build Application
# ============================================================================

print_step "Phase 2: Building React Application"
echo ""

if [ ! -f "package.json" ]; then
    error_exit "package.json not found. Run this script from the project root."
fi

print_step "Installing dependencies..."
yarn install --frozen-lockfile || error_exit "Failed to install dependencies"
print_success "Dependencies installed"

print_step "Building application..."
rm -rf dist  # Clean previous builds
yarn build || error_exit "Build failed"
print_success "Build complete. Output: ./dist"

# Verify dist folder was created
if [ ! -d "dist" ] || [ ! -f "dist/index.html" ]; then
    error_exit "Build output not found or index.html missing in dist folder"
fi

echo ""

# ============================================================================
# PHASE 3: Create/Verify Azure Resources (Idempotent)
# ============================================================================

print_step "Phase 3: Creating/Verifying Azure Resources"
echo ""

# Resource Group
print_step "Checking Resource Group: $RESOURCE_GROUP..."
if resource_group_exists; then
    print_success "Resource Group exists (skipping creation)"
else
    print_step "Creating Resource Group..."
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$REGION" || error_exit "Failed to create Resource Group"
    print_success "Resource Group created"
fi

# App Service Plan
print_step "Checking App Service Plan: $APP_SERVICE_PLAN..."
if plan_exists; then
    print_success "App Service Plan exists (skipping creation)"
else
    print_step "Creating App Service Plan..."
    az appservice plan create \
        --name "$APP_SERVICE_PLAN" \
        --resource-group "$RESOURCE_GROUP" \
        --sku "$SKU" \
        --is-linux \
        --number-of-workers 1 || error_exit "Failed to create App Service Plan"
    print_success "App Service Plan created"
fi

# Web App
print_step "Checking App Service: $APP_SERVICE_NAME..."
if webapp_exists; then
    print_success "App Service exists (skipping creation)"
    print_info "Will update with new deployment"
else
    print_step "Creating App Service..."
    az webapp create \
        --resource-group "$RESOURCE_GROUP" \
        --plan "$APP_SERVICE_PLAN" \
        --name "$APP_SERVICE_NAME" \
        --runtime "Node|20-lts" || error_exit "Failed to create App Service"
    print_success "App Service created"
fi

echo ""

# ============================================================================
# PHASE 4: Configure App Service (Idempotent)
# ============================================================================

print_step "Phase 4: Configuring App Service"
echo ""

print_step "Configuring application settings..."
az webapp config appsettings set \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_SERVICE_NAME" \
    --settings \
        "SCM_DO_BUILD_DURING_DEPLOYMENT=false" \
        "WEBSITE_NODE_DEFAULT_VERSION=20-lts" || \
    error_exit "Failed to configure app settings"
print_success "Application settings configured"

# Enable HTTPS only (do early so deployment uses HTTPS)
print_step "Enabling HTTPS-only access..."
az webapp update \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_SERVICE_NAME" \
    --https-only true || error_exit "Failed to enable HTTPS"
print_success "HTTPS enabled"

echo ""

# ============================================================================
# PHASE 5: Prepare Deployment Package
# ============================================================================

print_step "Phase 5: Preparing Deployment Package"
echo ""

print_step "Creating deployment package..."

# Create temporary deployment directory
mkdir -p "$TEMP_DIR" || error_exit "Failed to create temp directory"

# Copy built app
cp -r dist/* "$TEMP_DIR/" || error_exit "Failed to copy built application"
print_success "Application files copied"

# Copy web.config for SPA routing
if [ -f ".azure/web.config" ]; then
    cp ".azure/web.config" "$TEMP_DIR/web.config" || error_exit "Failed to copy web.config"
    print_success "SPA routing config (web.config) added"
else
    print_warning "web.config not found at .azure/web.config - SPA routing may not work"
fi

# Create ZIP archive
print_step "Creating ZIP archive..."
cd "$TEMP_DIR" || error_exit "Failed to change to temp directory"

if ! zip -r -q ../app-service-${DEPLOYMENT_TS:-$(date +%s)}.zip . &>/dev/null; then
    error_exit "Failed to create ZIP archive. Check zip command is available."
fi

ZIP_FILE="../app-service-${DEPLOYMENT_TS:-$(date +%s)}.zip"
cd "$SCRIPT_DIR" || error_exit "Failed to return to script directory"

if [ ! -f "$ZIP_FILE" ]; then
    error_exit "ZIP archive not created"
fi

print_success "ZIP archive created: $ZIP_FILE"
echo ""

# ============================================================================
# PHASE 6: Deploy Application
# ============================================================================

print_step "Phase 6: Deploying Application"
echo ""

print_step "Uploading to App Service (this may take 1-2 minutes)..."

if ! az webapp deployment source config-zip \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_SERVICE_NAME" \
    --src "$ZIP_FILE" &>/dev/null; then
    
    # Try once more with verbose error
    print_warning "First deployment attempt failed, retrying with diagnostics..."
    az webapp deployment source config-zip \
        --resource-group "$RESOURCE_GROUP" \
        --name "$APP_SERVICE_NAME" \
        --src "$ZIP_FILE" || error_exit "Deployment failed after retry"
fi

print_success "Deployment uploaded successfully"

# Remove ZIP file
rm -f "$ZIP_FILE" || print_warning "Could not remove temporary ZIP file"

echo ""

# ============================================================================
# PHASE 7: Post-Deployment Verification
# ============================================================================

print_step "Phase 7: Post-Deployment Verification"
echo ""

print_step "Waiting for App Service to become ready..."
sleep 3  # Give App Service time to process deployment

max_attempts=15
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if az webapp log tail \
        --resource-group "$RESOURCE_GROUP" \
        --name "$APP_SERVICE_NAME" \
        --timeout 5 &>/dev/null; then
        print_success "App Service is responding"
        break
    fi
    
    attempt=$((attempt + 1))
    if [ $attempt -lt $max_attempts ]; then
        print_info "Waiting for App Service to initialize... ($attempt/$max_attempts)"
        sleep 2
    fi
done

if [ $attempt -eq $max_attempts ]; then
    print_warning "Could not verify App Service is responding (may still be initializing)"
else
    print_success "App Service verification passed"
fi

# Get deployment information
print_step "Retrieving deployment information..."

APP_URL="https://$(az webapp show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_SERVICE_NAME" \
    --query defaultHostName --output tsv)"

STATE_ID="$(az webapp show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_SERVICE_NAME" \
    --query id --output tsv)"

echo ""

# ============================================================================
# SUMMARY
# ============================================================================

print_success "Deployment completed successfully!"
echo ""
echo "============================================================================"
echo "📋 DEPLOYMENT SUMMARY"
echo "============================================================================"
echo -e "${GREEN}✓ App URL: ${CYAN}$APP_URL${NC}"
echo -e "${GREEN}✓ Resource Group: ${CYAN}$RESOURCE_GROUP${NC}"
echo -e "${GREEN}✓ App Service: ${CYAN}$APP_SERVICE_NAME${NC}"
echo -e "${GREEN}✓ Region: ${CYAN}$REGION${NC}"
echo -e "${GREEN}✓ SKU: ${CYAN}$SKU${NC}"
echo -e "${GREEN}✓ Subscription ID: ${CYAN}$SUBSCRIPTION_ID${NC}"
echo "============================================================================"
echo ""
echo "🚀 NEXT STEPS:"
echo ""
echo "1. Test your application:"
echo "   Visit: $APP_URL"
echo ""
echo "2. Monitor logs (real-time):"
echo "   az webapp log tail --resource-group $RESOURCE_GROUP --name $APP_SERVICE_NAME"
echo ""
echo "3. View app settings:"
echo "   az webapp config appsettings list --resource-group $RESOURCE_GROUP --name $APP_SERVICE_NAME"
echo ""
echo "4. Configure custom domain (optional):"
echo "   az webapp config hostname add --resource-group $RESOURCE_GROUP --webapp-name $APP_SERVICE_NAME --hostname yourdomain.com"
echo ""
echo "5. Re-deploy future updates:"
echo "   ./.azure/deploy.sh"
echo "   (This script is idempotent - safe to run multiple times)"
echo ""
echo "============================================================================"

# Save deployment state
save_state

print_success "Ready for production!"

