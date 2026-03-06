# Azure Static Web Apps CLI (swa) Scripts

## Overview

Your deployment scripts now use the official **Azure Static Web Apps CLI** (`swa`) for faster, more reliable deployments.

### What Changed

| Previous | Now | Benefit |
|----------|-----|---------|
| Manual `az` CLI calls | `swa deploy` command | ✅ Official SWA tool |
| Manual package creation | Automatic | ✅ Faster uploads |
| Manual verification | Built-in testing | ✅ Better reliability |

---

## 📋 Available Scripts

### 1. **`.azure/deploy.sh`** - Main Deployment
Deploy your app to Azure Static Web Apps using swa CLI.

```bash
# Basic deployment (auto-detects Azure resources)
./.azure/deploy.sh

# With specific resource
AZURE_RESOURCE_GROUP=my-rg AZURE_STATIC_WEB_APP=my-app ./.azure/deploy.sh
```

**What it does:**
- ✅ Loads config from `.azure/config.env`
- ✅ Auto-detects subscription, resource group, app
- ✅ Builds React app (`yarn build`)
- ✅ Deploys using `swa deploy`
- ✅ Verifies all routes responding
- ✅ Prints live app URL

### 2. **`.azure/start.sh`** - Local Development
Test locally with SWA routing before deploying.

```bash
# Start local dev server
./.azure/start.sh

# Custom port
PORT=3000 ./.azure/start.sh
```

**What it does:**
- ✅ Emulates Azure Static Web Apps locally
- ✅ Tests SPA routing (/* → index.html)
- ✅ Runs on http://localhost:4280
- ✅ Respects staticwebapp.config.json

### 3. **`.azure/upload-secure.sh`** - Manual Deployment
Deploy from command-line arguments (no hardcoded secrets).

```bash
./.azure/upload-secure.sh \
  --resource-group my-rg \
  --app-name my-app \
  --build-dir ./dist
```

---

## 🚀 Typical Workflow

### **1. Development & Testing**

```bash
# Build and test locally
./.azure/start.sh

# Test all routes at http://localhost:4280
# - http://localhost:4280/
# - http://localhost:4280/about
# - http://localhost:4280/contact-us
```

### **2. Deploy to Azure**

```bash
# Deploy using configuration
./.azure/deploy.sh

# Or with explicit parameters
AZURE_RESOURCE_GROUP="react-app-rg" \
AZURE_STATIC_WEB_APP="react-app-prod" \
./.azure/deploy.sh
```

### **3. Verify Deployment**

```bash
# Check app is live
curl https://gray-coast-04b895d0f.4.azurestaticapps.net/
curl https://gray-coast-04b895d0f.4.azurestaticapps.net/about
curl https://gray-coast-04b895d0f.4.azurestaticapps.net/contact-us
```

### **4. Enable GitHub Deployments (Optional)**

Once deployed, enable automatic deployments:

1. Go to: https://portal.azure.com
2. Find: `react-app-rg` > `react-app-prod`
3. Click: Deployment > Connect GitHub
4. Select: `blue-sun4/app-service-web-app`
5. Configure: App location: `/`, Output location: `dist`

Now every `git push` auto-deploys! 🎉

---

## 🔧 Configuration

### **Option 1: Config File** (Recommended)

```bash
# View/edit configuration
cat .azure/config.env

# Expected format:
AZURE_SUBSCRIPTION_ID="12345678-..."
AZURE_RESOURCE_GROUP="react-app-rg"
AZURE_STATIC_WEB_APP="react-app-prod"
AZURE_REGION="eastus2"
AZURE_BUILD_DIR="./dist"
```

### **Option 2: Environment Variables**

```bash
export AZURE_RESOURCE_GROUP="react-app-rg"
export AZURE_STATIC_WEB_APP="react-app-prod"
./.azure/deploy.sh
```

### **Option 3: Command Arguments**

```bash
./.azure/upload-secure.sh \
  --resource-group react-app-rg \
  --app-name react-app-prod
```

### **Option 4: Auto-Detection**

Scripts auto-detect if you have only one resource group and app:

```bash
./.azure/deploy.sh  # Just works!
```

---

## 📊 Script Capabilities

### **deploy.sh**
```
Phase 1: Configuration
  ├─ Load .azure/config.env
  ├─ Read environment variables
  ├─ Auto-detect subscriptions/resources
  └─ Validate authentication

Phase 2: Validation
  ├─ Check build directory
  ├─ Verify index.html
  └─ Locate swa CLI

Phase 3: Build
  ├─ Run: yarn build
  ├─ Verify output
  └─ Check index.html

Phase 4: Get Credentials
  ├─ Retrieve deployment token
  ├─ Save token securely (mode: 600)
  └─ Validate token

Phase 5: Deploy with SWA
  ├─ Run: swa deploy ./dist
  ├─ Use deployment token
  └─ Deploy to production

Phase 6: Get App Details
  ├─ Retrieve app hostname
  └─ Get resource URL

Phase 7: Verify Routes
  ├─ Test home: http://app/
  ├─ Test about: http://app/about
  └─ Test contact: http://app/contact-us
```

---

## 🔐 Security

✅ **Configuration file ignored by git** (in `.gitignore`)  
✅ **Deployment token stored securely** (mode 600)  
✅ **No hardcoded secrets** in scripts  
✅ **Uses Azure CLI authentication** (already logged in)  
✅ **Token auto-deleted** after deployment  

---

## 🐛 Troubleshooting

### **Error: "swa CLI not found"**
```bash
# Install swa CLI
yarn add -D @azure/static-web-apps-cli

# Verify installation
ls node_modules/.bin/swa
```

### **Error: "No resource groups found"**
```bash
# List available resource groups
az group list --query "[].name" -o table

# Create one if needed
az group create --name my-rg --location eastus2
```

### **Error: "Not authenticated"**
```bash
# Login to Azure
az login

# Verify subscription
az account show
```

### **Deployment succeeds but routes return 404**
```bash
# Check staticwebapp.config.json exists
ls -l dist/staticwebapp.config.json

# Verify SPA routing config
cat dist/staticwebapp.config.json | grep -A5 routes
```

### **Local testing (start.sh) not working**
```bash
# Build first
yarn build

# Then start
PORT=3000 ./.azure/start.sh

# Visit: http://localhost:3000
```

---

## 📝 Deployment Token

The deployment token is automatically:
- ✅ Retrieved from Azure
- ✅ Saved to `.azure/.deployment-token`
- ✅ Protected (mode 600 - read-only by owner)
- ✅ Used by `swa deploy` command
- ✅ Kept secure (not committed to git)

To view/use token:
```bash
cat .azure/.deployment-token
```

---

## 🎯 Common Tasks

### **Deploy Latest Changes**
```bash
git add .
git commit -m "Update app"
./.azure/deploy.sh
```

### **Test Before Deploying**
```bash
# Local testing first
./.azure/start.sh
# Visit http://localhost:4280

# Then deploy
./.azure/deploy.sh
```

### **Switch to Different App**
```bash
AZURE_STATIC_WEB_APP="different-app" ./.azure/deploy.sh
```

### **Redeploy Without Changes**
```bash
# Script is idempotent - safe to run multiple times
./.azure/deploy.sh
```

### **Check Deployment Status**
```bash
# View app details
az staticwebapp show \
  --name react-app-prod \
  --resource-group react-app-rg \
  --query "{hostname:defaultHostname, status:buildStatus}"
```

---

## 📚 More Information

- **swa CLI Docs:** https://github.com/Azure/static-web-apps-cli
- **Static Web Apps:** https://learn.microsoft.com/en-us/azure/static-web-apps/
- **Azure CLI:** https://learn.microsoft.com/en-us/cli/azure/

---

## ✨ Next Steps

1. **Build locally:**
   ```bash
   yarn build
   ```

2. **Test locally:**
   ```bash
   ./.azure/start.sh
   ```

3. **Deploy to Azure:**
   ```bash
   ./.azure/deploy.sh
   ```

4. **Enable GitHub (optional):**
   - Use Azure Portal Deployment tab
   - Connect GitHub for auto-deploy

---

**Happy Deploying with swa! 🚀**
