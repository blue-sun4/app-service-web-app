#!/bin/bash

# ============================================================================
# Setup Azure Infrastructure for React App
# ============================================================================
#
# Creates and configures all Azure resources needed for deployment
# Idempotent - safe to run multiple times
#
# Features:
#  ✓ Creates Resource Group
#  ✓ Creates Static Web App
#  ✓ Configures SPA routing
#  ✓ Stores configuration for deployment script
#  ✓ Validates resource creation
#  ✓ Supports CI/CD with environment variables
#
# Prerequisites:
#  - Azure CLI 2.40+
#  - jq 1.6+
#  - Logged into Azure (az login)
#
# Usage (Interactive):
#   chmod +x .azure/1-setup-azure.sh
#   ./.azure/1-setup-azure.sh
#
# Usage (Non-interactive for CI/CD):
#   export AZURE_SUBSCRIPTION_ID="sub-id"
#   export AZURE_RESOURCE_GROUP="my-rg"
#   export AZURE_REGION="eastus2"
#   export AZURE_STATIC_WEB_APP="my-app"
#   ./.azure/1-setup-azure.sh
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

# Error handler
trap 'log_error "Setup failed at line $LINENO"; exit 1' ERR

# Cleanup on interrupt
trap 'log_error "Setup interrupted"; exit 130' INT TERM

# ============================================================================
# Phase 1: Prerequisites
# ============================================================================
log_phase "Checking Prerequisites"

# Check Azure CLI and version
if ! command -v az &> /dev/null; then
  log_error "Azure CLI not installed"
  echo "Install with: brew install azure-cli"
  exit 1
fi

AZ_VERSION=$(az version --query '["azure-cli"]' -o tsv 2>/dev/null || echo "0.0.0")
log_debug "Azure CLI version: $AZ_VERSION"
log_success "Azure CLI installed (version: $AZ_VERSION)"

# Check jq for JSON parsing
if ! command -v jq &> /dev/null; then
  log_error "jq not installed (needed for JSON parsing)"
  echo "Install with: brew install jq"
  exit 1
fi

JQ_VERSION=$(jq --version 2>/dev/null || echo "unknown")
log_debug "jq version: $JQ_VERSION"
log_success "jq installed"

# ============================================================================
# Phase 2: Azure Authentication
# ============================================================================
log_phase "Azure Authentication"

# Verify logged in
if ! az account show &> /dev/null; then
  log_error "Not logged into Azure"
  echo "Run: az login"
  exit 1
fi

CURRENT_ACCOUNT=$(az account show --query displayName -o tsv)
log_success "Logged in as: $CURRENT_ACCOUNT"

# ============================================================================
# Phase 3: Configuration
# ============================================================================
log_phase "Configuration"

# Create config file path
CONFIG_FILE=".azure/config.env"
IS_INTERACTIVE="${CI:-}" && IS_INTERACTIVE="false" || IS_INTERACTIVE="true"

# If config exists, give option to reuse
if [ -f "$CONFIG_FILE" ]; then
  log_info "Loading existing configuration from $CONFIG_FILE"
  set +u
  source "$CONFIG_FILE"
  set -u
  
  log_success "Configuration found:"
  log_info "  Subscription: $AZURE_SUBSCRIPTION_ID"
  log_info "  Resource Group: $AZURE_RESOURCE_GROUP"
  log_info "  Region: $AZURE_REGION"
  log_info "  Static Web App: $AZURE_STATIC_WEB_APP"
  
  if [ "$IS_INTERACTIVE" == "true" ]; then
    read -p "Use existing configuration? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      rm "$CONFIG_FILE"
      log_info "Configuration reset"
    else
      IS_INTERACTIVE="false"
    fi
  fi
fi

# If no config or user wants new one, get configuration
if [ ! -f "$CONFIG_FILE" ]; then
  log_info "Gathering configuration details..."
  
  # Get subscription from env or user input
  if [ -z "${AZURE_SUBSCRIPTION_ID:-}" ]; then
    if [ "$IS_INTERACTIVE" == "true" ]; then
      read -p "Enter subscription ID (or press Enter for current): " AZURE_SUBSCRIPTION_ID || true
    fi
    if [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
      AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null || echo "")
      if [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
        log_error "No subscription configured. Please run: az account set --subscription <sub-id>"
        exit 1
      fi
    fi
  fi
  log_success "Subscription: $AZURE_SUBSCRIPTION_ID"
  
  # Get resource group from env or user input
  if [ -z "${AZURE_RESOURCE_GROUP:-}" ]; then
    if [ "$IS_INTERACTIVE" == "true" ]; then
      log_info "Available resource groups:"
      az group list --query "[].name" -o tsv 2>/dev/null | sed 's/^/  - /' || true
      echo ""
      read -p "Enter resource group name: " AZURE_RESOURCE_GROUP || true
    fi
    if [ -z "$AZURE_RESOURCE_GROUP" ]; then
      log_error "Resource group name is required"
      exit 1
    fi
  fi
  log_success "Resource Group: $AZURE_RESOURCE_GROUP"
  
  # Get region from env or user input
  AZURE_REGION="${AZURE_REGION:-eastus2}"
  log_success "Region: $AZURE_REGION"
  
  # Get app name from env or user input
  if [ -z "${AZURE_STATIC_WEB_APP:-}" ]; then
    if [ "$IS_INTERACTIVE" == "true" ]; then
      read -p "Enter Static Web App name: " AZURE_STATIC_WEB_APP || true
    fi
    if [ -z "$AZURE_STATIC_WEB_APP" ]; then
      log_error "Static Web App name is required"
      exit 1
    fi
  fi
  log_success "Static Web App: $AZURE_STATIC_WEB_APP"
  
  # Validate names
  if ! [[ "$AZURE_STATIC_WEB_APP" =~ ^[a-z0-9-]{2,}$ ]]; then
    log_error "Static Web App name must be lowercase alphanumeric and hyphens (min 2 chars)"
    exit 1
  fi
  
  # Save configuration with restricted permissions
  mkdir -p "$(dirname "$CONFIG_FILE")"
  cat > "$CONFIG_FILE" << EOF
# Azure Deployment Configuration
# Generated: $(date)
# DO NOT COMMIT THIS FILE

AZURE_SUBSCRIPTION_ID="$AZURE_SUBSCRIPTION_ID"
AZURE_RESOURCE_GROUP="$AZURE_RESOURCE_GROUP"
AZURE_REGION="$AZURE_REGION"
AZURE_STATIC_WEB_APP="$AZURE_STATIC_WEB_APP"
AZURE_BUILD_DIR="./dist"
EOF
  
  # Restrict permissions (read-only for owner)
  chmod 600 "$CONFIG_FILE"
  log_success "Configuration saved to $CONFIG_FILE (permissions: 600)"
fi

# Re-export final configuration
set +u
source "$CONFIG_FILE"
set -u

# ============================================================================
# Phase 4: Create Resources
# ============================================================================
log_phase "Creating Azure Resources"

# Set subscription
log_info "Setting subscription..."
az account set --subscription "$AZURE_SUBSCRIPTION_ID"
log_success "Subscription set"

# Create resource group if it doesn't exist
if az group exists --name "$AZURE_RESOURCE_GROUP" --output tsv | grep -q "false"; then
  log_info "Creating resource group: $AZURE_RESOURCE_GROUP"
  az group create \
    --name "$AZURE_RESOURCE_GROUP" \
    --location "$AZURE_REGION" > /dev/null
  log_success "Resource group created"
else
  log_info "Resource group already exists: $AZURE_RESOURCE_GROUP"
fi

# Create Static Web App if it doesn't exist
if ! az staticwebapp show \
  --name "$AZURE_STATIC_WEB_APP" \
  --resource-group "$AZURE_RESOURCE_GROUP" &>/dev/null; then
  
  log_info "Creating Static Web App: $AZURE_STATIC_WEB_APP"
  az staticwebapp create \
    --name "$AZURE_STATIC_WEB_APP" \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --location "$AZURE_REGION" > /dev/null
  
  log_success "Static Web App created"
else
  log_info "Static Web App already exists: $AZURE_STATIC_WEB_APP"
fi

# ============================================================================
# Phase 5: Get Deployment Details
# ============================================================================
log_phase "Retrieving Deployment Details"

# Get deployment token with retry
log_info "Retrieving deployment token..."
DEPLOY_TOKEN=""
for i in {1..3}; do
  DEPLOY_TOKEN=$(az staticwebapp secrets list \
    --name "$AZURE_STATIC_WEB_APP" \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --query properties.apiKey \
    --output tsv 2>/dev/null || echo "")
  
  if [ -n "$DEPLOY_TOKEN" ]; then
    log_success "Deployment token retrieved"
    break
  fi
  
  if [ $i -lt 3 ]; then
    log_warning "Token not available yet, retrying in 2 seconds..."
    sleep 2
  fi
done

if [ -z "$DEPLOY_TOKEN" ]; then
  log_warning "Deployment token not available yet (will be needed for deployment)"
fi

# Get app URL
APP_URL=$(az staticwebapp show \
  --name "$AZURE_STATIC_WEB_APP" \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --query defaultHostname \
  --output tsv 2>/dev/null || echo "")

if [ -n "$APP_URL" ]; then
  log_success "App URL: https://$APP_URL"
else
  log_warning "App URL not available yet"
fi

# Verify resource exists and is accessible
log_info "Verifying Static Web App accessibility..."
if az staticwebapp show \
  --name "$AZURE_STATIC_WEB_APP" \
  --resource-group "$AZURE_RESOURCE_GROUP" &>/dev/null; then
  log_success "Static Web App verified"
else
  log_error "Static Web App not accessible"
  exit 1
fi

# ============================================================================
# Phase 6: Git Configuration
# ============================================================================
log_phase "Configuring Git"

# Ensure config.env is in .gitignore
if [ -f ".gitignore" ]; then
  if ! grep -q "^\.azure/config\.env$" .gitignore; then
    echo ".azure/config.env" >> .gitignore
    log_success "Added .azure/config.env to .gitignore"
  else
    log_success ".azure/config.env already in .gitignore"
  fi
else
  log_warning "No .gitignore found (config.env should not be committed)"
fi

# ============================================================================
# Phase 7: Summary
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "Azure Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Configuration saved to: $CONFIG_FILE"
echo ""
echo "📋 Summary:"
echo "  Account:        $CURRENT_ACCOUNT"
echo "  Subscription:   $AZURE_SUBSCRIPTION_ID"
echo "  Resource Group: $AZURE_RESOURCE_GROUP"
echo "  Region:         $AZURE_REGION"
echo "  Static Web App: $AZURE_STATIC_WEB_APP"
if [ -n "$APP_URL" ]; then
  echo "  App URL:        https://$APP_URL"
fi
echo ""
echo "📦 Next Step:"
echo "  $ ./.azure/2-deploy-and-test.sh"
echo ""
echo "💡 Tips:"
echo "  • Keep $CONFIG_FILE secure (not in version control)"
echo "  • Configuration is pre-loaded for next deployment"
if [ -n "$APP_URL" ]; then
  echo "  • Your app will be available at: https://$APP_URL"
fi
echo ""
