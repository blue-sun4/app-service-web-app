# Deployment Scripts

Two simple scripts to manage your Azure Static Web Apps deployment:

## 📋 Scripts

### 1. Setup Azure Infrastructure (Run Once)
```bash
./.azure/1-setup-azure.sh
```

**What it does:**
- ✓ Verifies Azure CLI and authentication
- ✓ Creates/configures Resource Group
- ✓ Creates Static Web App
- ✓ Stores configuration in `.azure/config.env`

**When to run:** First time setting up Azure

---

### 2. Build, Deploy & Test (Run Each Deploy)
```bash
./.azure/2-deploy-and-test.sh
```

**What it does:**
- ✓ Builds your React application
- ✓ Deploys to Azure Static Web Apps
- ✓ Tests all routes (/, /about, /contact-us)
- ✓ Verifies deployment succeeded

**Options:**
```bash
# Skip route testing
./.azure/2-deploy-and-test.sh --skip-tests

# Deploy and push to Git
./.azure/2-deploy-and-test.sh --with-git
```

**When to run:** Every time you want to deploy changes

---

## 🚀 Quick Start

```bash
# 1. Setup Azure (first time only)
./.azure/1-setup-azure.sh

# 2. Deploy and test
./.azure/2-deploy-and-test.sh

# 3. Deploy with Git push (optional)
./.azure/2-deploy-and-test.sh --with-git
```

---

## 🔧 Configuration

Settings are stored in `.azure/config.env`:
```env
AZURE_SUBSCRIPTION_ID="..."
AZURE_RESOURCE_GROUP="react-app-rg"
AZURE_REGION="eastus2"
AZURE_STATIC_WEB_APP="react-app-prod"
AZURE_BUILD_DIR="./dist"
```

Edit manually or run `1-setup-azure.sh` again to reconfigure.

---

## ✅ Prerequisites

Required tools:
- Azure CLI: `brew install azure-cli`
- jq: `brew install jq`
- Node.js & yarn: Already installed
- swa CLI: Installed automatically if missing

Ensure you're logged in:
```bash
az login
```

---

## 🐛 Troubleshooting

**"Azure CLI not installed"**
```bash
brew install azure-cli
```

**"jq not installed"**
```bash
brew install jq
```

**"swa CLI not found"**
```bash
yarn add -D @azure/static-web-apps-cli
```

**"Not logged into Azure"**
```bash
az login
```

---

## 📚 Related Commands

**View live logs:**
```bash
az staticwebapp logs \
  --name react-app-prod \
  --resource-group react-app-rg
```

**View deployment status:**
```bash
az staticwebapp show \
  --name react-app-prod \
  --resource-group react-app-rg
```

**Local development:**
```bash
yarn dev
```

---

## 🗂️ File Structure

```
.azure/
├── 1-setup-azure.sh       # Setup Azure infrastructure
├── 2-deploy-and-test.sh   # Build, deploy, and test
├── config.env             # Configuration (auto-generated)
├── staticwebapp.config.json # SPA routing config
└── README.md              # This file
```

---

## 📝 What changed

Consolidated 9 scripts into 2 focused scripts:
- `init-config.sh` → merged into `1-setup-azure.sh`
- `deploy.sh`, `deploy-local.sh`, `deploy-swa.sh` → merged into `2-deploy-and-test.sh`
- `upload.sh`, `upload-secure.sh` → merged into `2-deploy-and-test.sh`
- Removed deprecated App Service scripts

Follow the individual step-by-step commands in:
- `.azure/DEPLOYMENT-GUIDE.md` (detailed instructions)
- `.azure/QUICK-DEPLOY.md` (quick reference)

### Option 3: GitHub Actions CI/CD

Push to main branch and GitHub automatically builds and deploys:

```bash
git push origin main
```

Monitor deployment in GitHub → Actions tab.

---

## 📋 Configuration

### Before Deploying

Edit variables in `.azure/deploy.sh`:

```bash
SUBSCRIPTION_ID="2165d0b7-5e28-4054-9df0-10871d681f2c"  # ✅ Already set
RESOURCE_GROUP="react-app-rg"                            # 👈 Change if needed
APP_SERVICE_NAME="react-app-${RANDOM}"                   # 👈 Change if needed
REGION="eastus"                                          # 👈 Change if needed
SKU_SIZE="S1"                                            # 👈 Change for free tier (F1)
```

### Key Resources Created

```
Resource Group: react-app-rg
├── App Service Plan: react-app-plan (Linux, Standard S1)
└── App Service: react-app-XXXXX
    ├── Runtime: Node.js 20 LTS (for static serving)
    ├── HTTPS: Enabled
    ├── Region: eastus
    └── URL: https://react-app-XXXXX.azurewebsites.net
```

---

## 🔍 What's Inside

### web.config (IIS Configuration)

✅ Enables SPA routing (all routes return index.html)
✅ Gzip compression for better performance
✅ Security headers (XSS, clickjacking protection)
✅ HTTPS redirect (HTTP → HTTPS)
✅ Caching headers for static assets

### deploy.sh (Automated Script)

✅ Pre-flight checks (Azure CLI, Yarn installed)
✅ Builds React app with Vite
✅ Creates all Azure resources
✅ Handles deployment with ZIP deploy
✅ Enables HTTPS
✅ Provides summary of deployed app

---

## ✅ Pre-Deployment Checklist

- [ ] Azure CLI installed and logged in (`az login`)
- [ ] Yarn installed locally
- [ ] React app builds locally (`yarn build`)
- [ ] Azure subscription ID verified
- [ ] No sensitive data in repository

---

## 📊 Deployment Target

| Property | Value |
|----------|-------|
| **Service** | Azure App Service (Web App) |
| **OS** | Linux |
| **Runtime** | Node.js 20 LTS |
| **SKU** | Standard S1 (~$75/month) |
| **Region** | eastus |
| **HTTPS** | ✅ Enabled |
| **Routing** | ✅ SPA routing configured |

---

## 🎯 After Deployment

### View Your App

```bash
# Get the live URL
az webapp show \
  --resource-group "react-app-rg" \
  --name "YOUR-APP-NAME" \
  --query defaultHostName
```

### Monitor Health

```bash
# View real-time logs
az webapp log tail --name "YOUR-APP-NAME"

# Check deployment status
az deployment group list --resource-group "react-app-rg"
```

### Performance Optimization

1. **Enable CDN** (Azure CDN) for faster global delivery
2. **Scale up** if needed (change SKU to S2, S3, etc.)
3. **Enable Application Insights** for detailed monitoring
4. **Set up custom domain** with SSL certificate

---

## ❌ Troubleshooting

| Issue | Solution |
|-------|----------|
| 404 errors on routes | Verify `web.config` is deployed in root of app |
| Deployment fails | Check Azure CLI is logged in: `az login` |
| Port connection refused | Check App Service plan running (not Free tier issue) |
| High latency | Scale up to larger SKU (S2, Premium) |
| Blue deployment page | App not fully deployed, wait 1-2 minutes |

See `.azure/DEPLOYMENT-GUIDE.md` for more troubleshooting.

---

## 💰 Cost Estimation

### Per Service (Monthly)

| Service | Cost |
|---------|------|
| App Service Plan (S1) | ~$75 |
| Data transfer (1GB) | ~$0.12 |
| Optional: Application Insights | ~$2.99 |
| **Total** | **~$75/month** |

### Cost Reduction Options

- Use **Free tier** (F1) for testing (limited features)
- Use **Shared tier** (D1) for light traffic
- Enable **auto-scaling** to match demand

---

## 🔄 CI/CD Setup (Optional)

To enable automatic deployment on every git push:

1. **Create Azure Service Principal:**
   ```bash
   az ad sp create-for-rbac \
     --name "react-app-deployment" \
     --role contributor \
     --sdk-auth
   ```

2. **Add to GitHub Secrets:**
   - Repo → Settings → Secrets → New secret
   - Name: `AZURE_CREDENTIALS`
   - Value: (paste JSON from step 1)

3. **Update GitHub Actions workflow:**
   - Edit `.github/workflows/azure-deploy.yml`
   - Change `AZURE_WEBAPP_NAME` to your app name

4. **Push and watch it deploy:**
   ```bash
   git push origin main
   ```

---

## 📚 Documentation Reference

- **Quick Deploy**: `.azure/QUICK-DEPLOY.md`
- **Full Guide**: `.azure/DEPLOYMENT-GUIDE.md`
- **Deployment Plan**: `.azure/plan.md`
- **Azure Docs**: https://learn.microsoft.com/azure/app-service/

---

## 🆘 Getting Help

1. **Check logs**: `az webapp log tail --name "app-name"`
2. **Azure Portal**: https://portal.azure.com
3. **Microsoft Docs**: https://learn.microsoft.com/azure/
4. **Common Issues**: See `.azure/DEPLOYMENT-GUIDE.md` → "Common Issues & Solutions"

---

## 🎉 Ready to Deploy?

Choose your method:

```bash
# Automated (recommended)
chmod +x .azure/deploy.sh
.azure/deploy.sh

# Or manual with commands from:
cat .azure/QUICK-DEPLOY.md

# Or with GitHub Actions:
git push origin main
```

Your React app will be live in minutes! 🚀
