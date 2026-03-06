# Secure Deployment - No Hardcoded Secrets

## Overview

All Azure deployment scripts have been updated to **eliminate hardcoded secrets**. 

No sensitive information should be stored in version control. This guide shows how to:
- ✅ Securely store deployment configuration
- ✅ Use environment variables
- ✅ Auto-detect Azure resources
- ✅ Protect credentials from git commits

---

## Quick Start (2 minutes)

### Step 1: Initialize Configuration

```bash
chmod +x .azure/init-config.sh
./.azure/init-config.sh
```

This wizard will:
- ✅ Verify Azure CLI authentication
- ✅ List your subscriptions and resource groups
- ✅ Detect existing Static Web Apps
- ✅ Generate `.azure/config.env` file

### Step 2: Verify Configuration

```bash
cat .azure/config.env
```

You should see (example):
```env
AZURE_SUBSCRIPTION_ID="12345678-1234-1234-1234-123456789012"
AZURE_RESOURCE_GROUP="my-rg"
AZURE_STATIC_WEB_APP="my-app"
```

### Step 3: Protect from Git

Ensure `.gitignore` includes:

```bash
# Add to .gitignore
.azure/config.env
.azure/.deployment-token
.env
```

Or merge the provided additions:
```bash
cat .azure/.gitignore-additions.txt >> .gitignore
```

### Step 4: Deploy

```bash
# Option 1: Automatically loads .azure/config.env
./.azure/deploy-swa.sh

# Option 2: Override with environment variables
export AZURE_RESOURCE_GROUP="different-rg"
./.azure/deploy-swa.sh

# Option 3: Command-line arguments
./.azure/upload-secure.sh --resource-group my-rg --app-name my-app
```

---

## Configuration Methods (Precedence Order)

The scripts use this precedence (highest to lowest):

### 1️⃣ Command-Line Arguments
```bash
./.azure/upload-secure.sh \
  --resource-group my-rg \
  --app-name my-app \
  --build-dir ./dist
```

### 2️⃣ Environment Variables
```bash
export AZURE_RESOURCE_GROUP="my-rg"
export AZURE_STATIC_WEB_APP="my-app"
./.azure/deploy-swa.sh
```

### 3️⃣ Config File (`.azure/config.env`)
```bash
# Automatically loaded by scripts
AZURE_RESOURCE_GROUP="my-rg"
AZURE_STATIC_WEB_APP="my-app"
```

### 4️⃣ Auto-Detection (from `az` CLI)
```bash
# If all above are empty, scripts auto-detect:
# - Subscription from current az login
# - Resource Group (if only one exists)
# - Static Web App (if only one exists in RG)
./.azure/deploy-swa.sh  # Works with no config!
```

---

## Available Configuration Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID | `12345678-...` |
| `AZURE_RESOURCE_GROUP` | Resource Group name | `my-rg` |
| `AZURE_STATIC_WEB_APP` | Static Web App name | `my-app` |
| `AZURE_REGION` | Azure region | `eastus2` |
| `AZURE_BUILD_DIR` | Build output directory | `./dist` |
| `AZURE_APP_LOCATION` | App location in repo | `/` |
| `AZURE_OUTPUT_LOCATION` | Build output location | `dist` |

---

## Deployment Scenarios

### Scenario 1: Single Developer (Local Machine)

```bash
# Setup once
./.azure/init-config.sh

# Deploy anytime (uses config.env)
./.azure/deploy-swa.sh
```

✅ Config file stays local, never committed to git

---

### Scenario 2: GitHub Actions (CI/CD)

**1. Create GitHub Secret:**
```bash
# In GitHub repo Settings > Secrets > New repository secret
Name: AZURE_TOKEN
Value: $(cat .azure/DEPLOYMENT_TOKEN.txt)
```

**2. Use in workflow (`.github/workflows/deploy.yml`):**
```yaml
- name: Deploy
  env:
    AZURE_RESOURCE_GROUP: ${{ secrets.AZURE_RESOURCE_GROUP }}
    AZURE_STATIC_WEB_APP: ${{ secrets.AZURE_STATIC_WEB_APP }}
  run: ./.azure/deploy-swa.sh
```

✅ All secrets stored in GitHub, never in code

---

### Scenario 3: Azure Pipelines (CI/CD)

**1. Create Pipeline Variables:**
```yaml
variables:
  AZURE_RESOURCE_GROUP: 'my-rg'
  AZURE_STATIC_WEB_APP: 'my-app'
```

**2. Use in pipeline:**
```yaml
- script: ./.azure/deploy-swa.sh
  env:
    AZURE_RESOURCE_GROUP: $(AZURE_RESOURCE_GROUP)
    AZURE_STATIC_WEB_APP: $(AZURE_STATIC_WEB_APP)
```

✅ Variables encrypted in Azure, safe from exposure

---

### Scenario 4: Docker / Container Deployment

```dockerfile
FROM node:20-alpine

WORKDIR /app
COPY . .

RUN chmod +x .azure/deploy-swa.sh

# Pass env vars at runtime
CMD ["./.azure/deploy-swa.sh"]
```

**Run container:**
```bash
docker run \
  -e AZURE_SUBSCRIPTION_ID="..." \
  -e AZURE_RESOURCE_GROUP="my-rg" \
  -e AZURE_STATIC_WEB_APP="my-app" \
  -v ~/.azure:/root/.azure \
  my-app:latest
```

✅ Credentials passed at runtime, not baked into image

---

## Advanced: Multiple Environments

Deploy to different environments without hardcoding:

```bash
# Development
export AZURE_RESOURCE_GROUP="dev-rg"
export AZURE_STATIC_WEB_APP="my-app-dev"
./.azure/deploy-swa.sh

# Staging
export AZURE_RESOURCE_GROUP="staging-rg"
export AZURE_STATIC_WEB_APP="my-app-staging"
./.azure/deploy-swa.sh

# Production
export AZURE_RESOURCE_GROUP="prod-rg"
export AZURE_STATIC_WEB_APP="my-app-prod"
./.azure/deploy-swa.sh
```

Or with separate config files:

```bash
# .azure/config.dev.env
AZURE_RESOURCE_GROUP="dev-rg"
AZURE_STATIC_WEB_APP="my-app-dev"

# .azure/config.prod.env
AZURE_RESOURCE_GROUP="prod-rg"
AZURE_STATIC_WEB_APP="my-app-prod"

# Deploy to different environments
source .azure/config.dev.env && ./.azure/deploy-swa.sh
source .azure/config.prod.env && ./.azure/deploy-swa.sh
```

---

## Security Checklist

- ✅ **`.azure/config.env` is in `.gitignore`** - Prevents accidental commits
- ✅ **Deployment token stored securely** - Mode 600 (-rw-------)
- ✅ **No secrets in environment startup** - Loaded at runtime
- ✅ **No hardcoded values in scripts** - All configurable
- ✅ **Use managed identities** - When available in CI/CD
- ✅ **Rotate tokens regularly** - Regenerate deployment tokens
- ✅ **Use encrypted storage** - GitHub Secrets, Azure KeyVault, etc.

---

## Troubleshooting

### Error: "No resource groups found"
```bash
# Verify you're logged in
az login
az group list
```

### Error: "No Static Web Apps found"
```bash
# Check resource group name
az staticwebapp list --resource-group YOUR_RG_NAME
```

### Scripts don't load config
```bash
# Verify config file exists and is readable
ls -l .azure/config.env
cat .azure/config.env
```

### Environment variables not working
```bash
# Verify export (not just assignment)
export AZURE_RESOURCE_GROUP="my-rg"
printenv | grep AZURE
```

---

## Files Reference

| File | Purpose | Git Status |
|------|---------|-----------|
| `.azure/deploy-swa.sh` | Main deployment script | ✅ Track |
| `.azure/upload-secure.sh` | Secure upload script | ✅ Track |
| `.azure/init-config.sh` | Config wizard | ✅ Track |
| `.azure/config.env.example` | Config template | ✅ Track |
| `.azure/config.env` | Your config (LOCAL) | ❌ .gitignore |
| `.azure/.deployment-token` | Secure token (LOCAL) | ❌ .gitignore |

---

## Next Steps

1. **Initialize:** `chmod +x .azure/init-config.sh && ./.azure/init-config.sh`
2. **Review:** `cat .azure/config.env`
3. **Protect:** `echo ".azure/config.env" >> .gitignore`
4. **Deploy:** `./.azure/deploy-swa.sh`
5. **Store token safely:** Add to GitHub Secrets or Azure KeyVault

---

**No more hardcoded secrets! 🔒**
