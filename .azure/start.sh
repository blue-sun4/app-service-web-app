#!/bin/bash

# ============================================================================
# Local Development with Azure Static Web Apps CLI
# ============================================================================
#
# Test your React app locally with SWA emulation
# Uses @azure/static-web-apps-cli for local development
#
# Features:
#   ✓ Emulates Azure Static Web Apps routing locally
#   ✓ SPA routing support (/* routes to index.html)
#   ✓ Configuration preview
#   ✓ Live reload support
#
# Usage:
#   ./.azure/start.sh
#   PORT=3000 ./.azure/start.sh
#
# ============================================================================

set -euo pipefail

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}→${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_title() { echo -e "\n${BLUE}$1${NC}\n"; }

# Configuration
BUILD_DIR="${AZURE_BUILD_DIR:-./dist}"
PORT="${PORT:-4280}"
CONFIG_FILE="${BUILD_DIR}/staticwebapp.config.json"

log_title "Azure Static Web Apps - Local Development"

# Check prerequisites
log_info "Checking prerequisites..."
if ! command -v node &> /dev/null; then
  echo "✗ Node.js not installed"
  exit 1
fi
log_success "Node.js installed"

# Check swa CLI
if [ ! -f "node_modules/.bin/swa" ]; then
  echo "✗ swa CLI not installed"
  echo "Install with: yarn add -D @azure/static-web-apps-cli"
  exit 1
fi
log_success "swa CLI available"

# Build if dist doesn't exist
if [ ! -d "$BUILD_DIR" ]; then
  log_info "Building application..."
  yarn build > /dev/null
fi
log_success "Build directory verified"

# Show configuration
log_info "Configuration:"
echo "  Build directory: $BUILD_DIR"
echo "  Local port: http://localhost:$PORT"
echo "  Config file: $CONFIG_FILE"

# Show route configuration if exists
if [ -f "$CONFIG_FILE" ]; then
  echo ""
  log_info "SPA Routes configured:"
  cat "$CONFIG_FILE" | grep -A 5 '"routes"' | head -10 || true
fi

echo ""
log_success "Starting SWA emulator..."
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Application running at: http://localhost:$PORT"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Routes to test:"
echo "  • Home:    http://localhost:$PORT/"
echo "  • About:   http://localhost:$PORT/about"
echo "  • Contact: http://localhost:$PORT/contact-us"
echo ""
echo "Press Ctrl+C to stop"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Start swa emulator
node_modules/.bin/swa start "$BUILD_DIR" \
  --host localhost \
  --port "$PORT" \
  --swa-config-location "$BUILD_DIR"

