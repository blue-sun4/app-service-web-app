# Quick Deploy Guide

Deploy your React app to Azure App Service in minutes.

## 📋 Prerequisites

- Azure CLI installed: https://learn.microsoft.com/cli/azure/install-azure-cli
- Azure subscription with:
  - Subscription ID: `2165d0b7-5e28-4054-9df0-10871d681f2c`
  - Proper permissions to create resources
- Logged in: `az login`

## 🚀 Quickest Method: Run the Script

```bash
# Make the script executable
chmod +x .azure/deploy.sh

# Run the automated deployment
.azure/deploy.sh
```

The script will:
1. ✅ Validate dependencies
2. ✅ Build your React app
3. ✅ Create Azure resources (Resource Group, App Service Plan, App Service)
4. ✅ Deploy the application
5. ✅ Configure HTTPS
6. ✅ Print your App URL

**Total time**: 5-10 minutes

---

## 📝 Manual Deployment (Per Step)

If you prefer to run commands individually:

### Step 1: Build Locally
```bash
yarn install
yarn build
```

### Step 2: Set Subscription
```bash
az account set --subscription "2165d0b7-5e28-4054-9df0-10871d681f2c"
```

### Step 3: Create Resource Group
```bash
az group create --name "react-app-rg" --location "eastus"
```

### Step 4: Create App Service Plan
```bash
az appservice plan create \
  --name "react-app-plan" \
  --resource-group "react-app-rg" \
  --sku "Standard@S1" \
  --is-linux
```

### Step 5: Create App Service
```bash
az webapp create \
  --resource-group "react-app-rg" \
  --plan "react-app-plan" \
  --name "react-app-unique-name" \
  --runtime "Node|20-lts"
```

### Step 6: Deploy via ZIP
```bash
# Package the app
cd dist
zip -r ../app.zip .
cd ..

# Deploy
az webapp deployment source config-zip \
  --resource-group "react-app-rg" \
  --name "react-app-unique-name" \
  --src app.zip
```

---

## 🎯 Customization Options

### Change Configuration

Edit `.azure/plan.md` to modify:
- **App name**: Line with `RESOURCE_GROUP` and `APP_SERVICE_NAME`
- **Region**: Change `REGION="eastus"` to another region
- **SKU**: Change `SKU_SIZE="S1"` to `F1` (free) or `S2` (larger)

### Change Resource Names

In `.azure/deploy.sh`, modify at the top:
```bash
RESOURCE_GROUP="my-custom-rg"           # Change name
APP_SERVICE_PLAN="my-app-plan"          # Change name
APP_SERVICE_NAME="my-unique-app-name"   # Must be globally unique!
```

---

## 🔍 After Deployment

### Get Your App URL
```bash
az webapp show \
  --resource-group "react-app-rg" \
  --name "react-app-prod" \
  --query defaultHostName --output tsv
```

### View Live Logs
```bash
az webapp log tail \
  --resource-group "react-app-rg" \
  --name "react-app-prod"
```

### Scale Up (if needed)
```bash
az appservice plan update \
  --name "react-app-plan" \
  --sku "Premium@P2V2"
```

---

## ❌ Troubleshooting

| Issue | Solution |
|-------|----------|
| "404 Not Found" on routes | web.config is missing SPA rewrite rules. Ensure it's deployed. |
| "App shows default page" | Check deployment logs: `az webapp log tail --name "your-app"` |
| "Permission denied" | Login again: `az login` and set subscription |
| "App name not available" | Use a more unique name, add timestamp or random suffix |
| "High latency after deploy" | Scale up: Change SKU to S2 or higher |

---

## 🗑️ Delete Everything (Clean Up)

```bash
# Delete entire resource group and ALL resources
az group delete --name "react-app-rg" --yes --no-wait
```

---

## 📚 Full Documentation

For detailed information, see: `.azure/DEPLOYMENT-GUIDE.md`

---

## 🔄 CI/CD with GitHub Actions (Optional)

### Setup:

1. **Create Azure credentials:**
   ```bash
   az ad sp create-for-rbac \
     --name "react-app-deployment" \
     --role contributor \
     --scopes /subscriptions/2165d0b7-5e28-4054-9df0-10871d681f2c \
     --sdk-auth
   ```

2. **Add secret to GitHub:**
   - Go to your GitHub repo → Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `AZURE_CREDENTIALS`
   - Value: (paste the JSON output from step 1)

3. **GitHub Actions will:**
   - Automatically build and deploy on every push to `main`
   - Workflow file: `.github/workflows/azure-deploy.yml`

### Trigger Deployment:
```bash
git push origin main
```

Monitor deployment in GitHub → Actions tab.

---

## 💰 Estimated Monthly Costs

| Service | Cost (USD) |
|---------|-----------|
| App Service Plan (Standard S1) | ~$75 |
| Data transfer (outbound) | ~$0.12/GB |
| **Total (small app)** | **~$75/month** |

**To reduce costs**: Use Free or Shared tier (for testing only)

---

## ✅ Checklist

Before deploying:
- [ ] React app builds locally (`yarn build`)
- [ ] Azure CLI is installed and logged in
- [ ] Subscription ID is correct
- [ ] Resource names are unique
- [ ] No sensitive data in code

After deploying:
- [ ] App loads at the provided URL
- [ ] Navigation between pages works
- [ ] Contact form submits successfully
- [ ] HTTPS is enabled

---

## 🆘 Need Help?

1. Check logs: `az webapp log tail --name "your-app"`
2. Read full guide: `.azure/DEPLOYMENT-GUIDE.md`
3. Azure Portal: https://portal.azure.com
4. Documentation: https://learn.microsoft.com/azure/app-service/
