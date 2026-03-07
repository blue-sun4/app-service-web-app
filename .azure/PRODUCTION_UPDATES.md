# Production-Ready CLI Scripts - Updates Summary

## Overview
Both Azure deployment scripts have been thoroughly reviewed and updated to meet production-ready standards for Git and CI/CD environments.

**Updated Scripts:**
- `1-setup-azure.sh` - Azure infrastructure setup
- `2-deploy-and-test.sh` - Application deployment and testing

---

## 1️⃣ `1-setup-azure.sh` - Setup and Configuration

### ✨ New Features
- **Non-interactive CI/CD mode** - Supports configuring via environment variables for pipeline automation
- **Version checking** - Validates Azure CLI and jq versions
- **Configuration validation** - Ensures all required variables are present
- **Secure config storage** - Sets restrictive file permissions (600) on config.env
- **Git integration** - Automatically adds config.env to .gitignore
- **Retry logic** - Retries deployment token retrieval (up to 3 attempts)
- **Resource verification** - Validates resources are accessible after creation
- **Debug mode** - Use `DEBUG=1` for detailed logging
- **Better error messages** - Contextual help when operations fail

### 🔒 Security Improvements
- Configuration file has restrictive permissions (`chmod 600`)
- Sensitive credentials are not echoed to console
- Automatic .gitignore configuration for config.env
- Clear warning to not commit configuration

### 📋 Usage Examples

**Interactive Mode (Default):**
```bash
chmod +x .azure/1-setup-azure.sh
./.azure/1-setup-azure.sh
```

**CI/CD Mode (Non-interactive):**
```bash
export AZURE_SUBSCRIPTION_ID="sub-xxx"
export AZURE_RESOURCE_GROUP="my-rg"
export AZURE_REGION="eastus2"
export AZURE_STATIC_WEB_APP="my-app"
./.azure/1-setup-azure.sh
```

**Debug Mode:**
```bash
DEBUG=1 ./.azure/1-setup-azure.sh
```

### 🔧 Configuration
The script creates `.azure/config.env` with:
```env
AZURE_SUBSCRIPTION_ID="..."
AZURE_RESOURCE_GROUP="..."
AZURE_REGION="..."
AZURE_STATIC_WEB_APP="..."
AZURE_BUILD_DIR="./dist"
```

---

## 2️⃣ `2-deploy-and-test.sh` - Deployment and Verification

### ✨ New Features
- **Clean build process** - Removes old dist/ before building (prevents stale files)
- **Skip build option** - `--skip-build` for faster redeployments
- **Multiple package managers** - Works with both yarn and npm
- **Enhanced testing** - Better HTTP status code handling
- **Secure token handling** - Deployment token not logged (safe for logs)
- **Git-aware deployment** - Intelligently handles git commits and excludes build artifacts
- **Configuration validation** - Ensures all required values are present
- **Build size reporting** - Shows dist/ size after build
- **CI/CD compatible** - Non-interactive mode when `CI=true`
- **Debug mode** - Use `DEBUG=1` for detailed logging
- **Interrupt handling** - Graceful cleanup on Ctrl+C

### 🔒 Security Improvements
- Deployment tokens not displayed (safe for CI logs)
- Build artifacts (dist/, node_modules/) excluded from git commits
- Config.env validation before deployment
- No hardcoded sensitive data

### 📋 Usage Examples

**Standard Deployment:**
```bash
./.azure/2-deploy-and-test.sh
```

**Skip Tests (Faster):**
```bash
./.azure/2-deploy-and-test.sh --skip-tests
```

**Skip Build (Redeploy existing build):**
```bash
./.azure/2-deploy-and-test.sh --skip-build
```

**With Git Commit and Push:**
```bash
./.azure/2-deploy-and-test.sh --with-git
```

**Multiple Options:**
```bash
./.azure/2-deploy-and-test.sh --skip-tests --skip-build --with-git
```

**CI/CD Mode (Non-interactive):**
```bash
CI=true ./.azure/2-deploy-and-test.sh
```

**Debug Mode:**
```bash
DEBUG=1 ./.azure/2-deploy-and-test.sh
```

### 🔧 Building Process
1. Validates prerequisites (Azure CLI, Node.js, yarn/npm, swa CLI)
2. Loads configuration from `.azure/config.env`
3. Cleans old build (removes dist/)
4. Builds with yarn/npm
5. Verifies build output (checks dist/index.html and size)
6. Deploys to Azure Static Web Apps
7. Verifies deployment (optional, tests HTTP routes)
8. Commits changes to Git (optional, excludes build artifacts)

### ⚙️ Git Integration
When using `--with-git`:
- Automatically adds `.gitignore` entries for dist/, node_modules/, .azure/config.env
- Excludes build artifacts from commits (only tracks source code)
- Handles existing/new repositories
- Safe for both local and CI/CD environments

---

## 📊 Comparison: Before vs After

| Feature | Before | After |
|---------|--------|-------|
| **CI/CD Support** | ❌ Interactive only | ✅ Environment variables |
| **Version Checks** | ❌ None | ✅ CLI tools verified |
| **Config Security** | ❌ Default permissions | ✅ Restrictive (600) |
| **Token Safety** | ⚠️ Could be logged | ✅ Never displayed |
| **Build Cleanliness** | ⚠️ Reuses old builds | ✅ Clean builds |
| **Git Integration** | ⚠️ Could add dist/ | ✅ Excludes build artifacts |
| **Error Messages** | ⚠️ Generic | ✅ Contextual help |
| **Debug Mode** | ❌ None | ✅ DEBUG=1 support |
| **Package Manager | ❌ Yarn only | ✅ Yarn + npm |
| **Retry Logic** | ❌ Single attempt | ✅ Retries (3x) |

---

## 🚀 Production Deployment Workflow

### Step 1: Initial Setup
```bash
# Set up Azure infrastructure once
./.azure/1-setup-azure.sh

# Or in CI/CD pipeline:
export AZURE_SUBSCRIPTION_ID="..."
export AZURE_RESOURCE_GROUP="..."
export AZURE_REGION="eastus2"
export AZURE_STATIC_WEB_APP="..."
./.azure/1-setup-azure.sh
```

### Step 2: Deploy Application
```bash
# Standard deployment with tests
./.azure/2-deploy-and-test.sh

# Or with git integration
./.azure/2-deploy-and-test.sh --with-git

# Or in CI/CD (non-interactive)
CI=true ./.azure/2-deploy-and-test.sh --with-git
```

### Step 3: Monitor (Optional)
```bash
# View logs
az staticwebapp logs \
  --name <APP_NAME> \
  --resource-group <RG_NAME>
```

---

## 🛡️ Security Checklist

- ✅ Configuration file (.azure/config.env) has restrictive permissions
- ✅ Configuration is excluded from git (.gitignore)
- ✅ Deployment tokens never logged
- ✅ Build artifacts excluded from git commits
- ✅ No hardcoded secrets
- ✅ Authentication required before deployment
- ✅ Proper error handling (fails fast on auth issues)

---

## 🔐 .gitignore Configuration

The scripts ensure these entries in `.gitignore`:
```
.azure/config.env              # Contains local Azure config
.azure/.deployment-token       # Deployment credentials
dist/                          # Build output
node_modules/                  # Dependencies
.env                           # Local environment
.env.local                     # Local secrets
```

---

## 📝 Environment Variables Reference

### Setup Script (1-setup-azure.sh)
| Variable | Purpose | Required |
|----------|---------|----------|
| `AZURE_SUBSCRIPTION_ID` | Azure subscription | Optional (uses current) |
| `AZURE_RESOURCE_GROUP` | Creating RG name | Optional (prompts) |
| `AZURE_REGION` | Azure region | Optional (defaults eastus2) |
| `AZURE_STATIC_WEB_APP` | Web app name | Optional (prompts) |
| `CI` | CI/CD mode flag | Optional |
| `DEBUG` | Enable debugging | Optional |

### Deploy Script (2-deploy-and-test.sh)
| Variable | Purpose | Required |
|----------|---------|----------|
| `CI` | Non-interactive mode | Optional |
| `DEBUG` | Enable debugging | Optional |

---

## 🐛 Troubleshooting

### Script Not Executable
```bash
chmod +x .azure/*.sh
```

### Configuration Not Found
```bash
# Ensure setup script was run first
./.azure/1-setup-azure.sh
```

### Deployment Token Fails
```bash
# Retry deployment (auto-retries but may need manual retry)
./.azure/2-deploy-and-test.sh --skip-build
```

### Build Fails
```bash
# Check for local build errors
yarn build  # or npm run build

# Use debug mode
DEBUG=1 ./.azure/2-deploy-and-test.sh
```

### Git Push Fails
```bash
# Configure git remote if not already done
git remote add origin https://github.com/user/repo.git

# Then deploy with git
./.azure/2-deploy-and-test.sh --with-git
```

---

## ✅ Production Readiness Checklist

- [x] Syntax validated (bash -n)
- [x] Error handling implemented
- [x] Configuration security enforced
- [x] CI/CD compatibility added
- [x] Git integration safe-by-default
- [x] Debug mode available
- [x] Version checks included
- [x] Retry logic for transient failures
- [x] Resource validation after creation
- [x] Comprehensive documentation
- [x] Clear error messages
- [x] Non-interactive mode support
- [x] Both yarn and npm support
- [x] Token security (not logged)
- [x] Build artifact exclusion from git

---

## 🔄 Next Steps

1. **Run Setup:** `./.azure/1-setup-azure.sh`
2. **Deploy:** `./.azure/2-deploy-and-test.sh`
3. **Git Integration:** `./.azure/2-deploy-and-test.sh --with-git`
4. **CI/CD Pipeline:** Set env vars and use `CI=true` flag
5. **Monitor:** Check logs and metrics in Azure Portal

---

**Last Updated:** March 6, 2026
**Status:** ✅ Production Ready
