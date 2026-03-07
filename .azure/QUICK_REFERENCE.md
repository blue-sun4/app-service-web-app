# Quick Reference - Azure Deployment Scripts

## One-Time Setup
```bash
./.azure/1-setup-azure.sh
```
Creates Azure infrastructure and saves config to `.azure/config.env`

---

## Deploy Application

### Standard Deployment
```bash
./.azure/2-deploy-and-test.sh
```
Builds, deploys, and tests the application.

### With Git Commit & Push
```bash
./.azure/2-deploy-and-test.sh --with-git
```
Includes git commit and push (excludes build artifacts).

### Skip Tests
```bash
./.azure/2-deploy-and-test.sh --skip-tests
```
Faster deployment without route verification.

### Reuse Build (Skip Build)
```bash
./.azure/2-deploy-and-test.sh --skip-build
```
Redeploy existing build without rebuilding.

### Combine Options
```bash
./.azure/2-deploy-and-test.sh --skip-tests --skip-build --with-git
```

---

## CI/CD Pipeline

### Setup Phase
```bash
export AZURE_SUBSCRIPTION_ID="your-sub-id"
export AZURE_RESOURCE_GROUP="your-rg"
export AZURE_REGION="eastus2"
export AZURE_STATIC_WEB_APP="your-app"
./.azure/1-setup-azure.sh
```

### Deploy Phase
```bash
CI=true ./.azure/2-deploy-and-test.sh --with-git
```
Non-interactive mode suitable for automated pipelines.

---

## Debugging

### Enable Debug Logging
```bash
DEBUG=1 ./.azure/2-deploy-and-test.sh
```

### Check Configuration
```bash
cat .azure/config.env
```

### View Deployment Logs
```bash
az staticwebapp logs --name <APP_NAME> --resource-group <RG_NAME>
```

---

## Key Files

| File | Purpose |
|------|---------|
| `.azure/1-setup-azure.sh` | Creates Azure resources (run once) |
| `.azure/2-deploy-and-test.sh` | Deploys application (run after changes) |
| `.azure/config.env` | Configuration (auto-created, excluded from git) |
| `.azure/PRODUCTION_UPDATES.md` | Detailed documentation |

---

## Important Notes

✅ **Always run setup first** before deploying  
🔒 **Never commit `.azure/config.env`** (automatically .gitignored)  
🚀 **Use `--with-git`** for proper git workflow  
🧹 **Build artifacts excluded** from git commits  
⚙️ **Supports yarn and npm** automatically  

---

**Status:** ✅ Production Ready | **Version:** 2.0
