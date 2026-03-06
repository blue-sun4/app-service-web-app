# Azure App Service Deployment - Manual CLI Commands

This document includes step-by-step Azure CLI commands to deploy your React app to Azure App Service.

## Prerequisites

1. **Azure CLI** installed: https://learn.microsoft.com/cli/azure/install-azure-cli
2. **Logged in to Azure**: `az login`
3. **Yarn installed locally**

## Configuration Variables

```bash
# Set these variables before running commands
SUBSCRIPTION_ID="2165d0b7-5e28-4054-9df0-10871d681f2c"
RESOURCE_GROUP="react-app-rg"
APP_SERVICE_PLAN="react-app-plan"
APP_SERVICE_NAME="react-app-prod"  # Must be globally unique
REGION="eastus"
SKU="Standard"
SKU_SIZE="S1"
```

---

## Step 1: Build Application Locally

Build your React application:

```bash
# Navigate to project directory
cd /path/to/app-service

# Install dependencies (if needed)
yarn install

# Build the application
yarn build

# This creates the 'dist' folder with optimized static files
```

---

## Step 2: Set Active Subscription

```bash
az account set --subscription "2165d0b7-5e28-4054-9df0-10871d681f2c"

# Verify subscription
az account show
```

---

## Step 3: Create Resource Group

```bash
az group create \
  --name "react-app-rg" \
  --location "eastus"

# Verify creation
az group show --name "react-app-rg"
```

---

## Step 4: Create App Service Plan

**Option A: Standard Plan (Recommended for Production)**

```bash
az appservice plan create \
  --name "react-app-plan" \
  --resource-group "react-app-rg" \
  --sku "Standard@S1" \
  --is-linux \
  --number-of-workers 1
```

**Option B: Free Plan (Testing Only)**

```bash
az appservice plan create \
  --name "react-app-plan" \
  --resource-group "react-app-rg" \
  --sku "Free@F1" \
  --is-linux
```

---

## Step 5: Create App Service

```bash
# Generate a unique app name (App Service names must be globally unique)
APP_NAME="react-app-$(date +%s)"

# Create the web app
az webapp create \
  --resource-group "react-app-rg" \
  --plan "react-app-plan" \
  --name "$APP_NAME" \
  --runtime "Node|20-lts"

# Save the app name for reference
echo "App Service Name: $APP_NAME"
```

---

## Step 6: Configure Application Settings

```bash
# Disable build during deployment (we're deploying pre-built files)
az webapp config appsettings set \
  --resource-group "react-app-rg" \
  --name "$APP_NAME" \
  --settings "SCM_DO_BUILD_DURING_DEPLOYMENT=false"

# Set Node version explicitly
az webapp config app-settings set \
  --resource-group "react-app-rg" \
  --name "$APP_NAME" \
  --settings "WEBSITE_NODE_DEFAULT_VERSION=20-lts"
```

---

## Step 7: Deploy Application (ZIP Deploy Method)

### Method A: Using ZIP Deployment (Recommended)

```bash
# Create deployment package from dist folder
cd dist
zip -r ../app-service-deploy.zip .

# Copy web.config to dist before zipping (for SPA routing)
cp ../web.config .
zip -r ../app-service-deploy.zip web.config
cd ..

# Deploy the ZIP file
az webapp deployment source config-zip \
  --resource-group "react-app-rg" \
  --name "$APP_NAME" \
  --src app-service-deploy.zip

# Cleanup
rm app-service-deploy.zip
```

### Method B: Using Azure App Service extension for VS Code

1. Install "Azure App Service" extension in VS Code
2. Sign in to Azure
3. Right-click on App Service in explorer
4. Select "Deploy to Web App"
5. Select the `dist` folder when prompted

---

## Step 8: Enable HTTPS

```bash
# Enable HTTPS-only
az webapp update \
  --resource-group "react-app-rg" \
  --name "$APP_NAME" \
  --https-only true

# View SSL settings
az webapp show \
  --resource-group "react-app-rg" \
  --name "$APP_NAME" \
  --query "{httpsOnly:httpsOnly, sslCertThumbprints:hostNames}"
```

---

## Step 9: Get Application URL

```bash
# Get the default URL
APP_URL=$(az webapp show \
  --resource-group "react-app-rg" \
  --name "$APP_NAME" \
  --query defaultHostName \
  --output tsv)

echo "App URL: https://$APP_URL"
```

---

## Step 10: Configure Custom Domain (Optional)

```bash
# Add custom domain
az webapp config hostname add \
  --resource-group "react-app-rg" \
  --webapp-name "$APP_NAME" \
  --hostname "yourdomain.com"

# Create SSL certificate binding
az webapp config ssl bind \
  --resource-group "react-app-rg" \
  --name "$APP_NAME" \
  --certificate-thumbprint "YOUR_CERT_THUMBPRINT" \
  --ssl-type SNI
```

---

## Step 11: View Deployment Logs

```bash
# Stream live logs
az webapp log tail \
  --resource-group "react-app-rg" \
  --name "$APP_NAME"

# Get recent logs
az webapp log download \
  --resource-group "react-app-rg" \
  --name "$APP_NAME" \
  --log-file logs.zip
```

---

## Step 12: Monitor and Troubleshoot

```bash
# View app configuration
az webapp config show \
  --resource-group "react-app-rg" \
  --name "$APP_NAME"

# View app settings
az webapp config appsettings list \
  --resource-group "react-app-rg" \
  --name "$APP_NAME"

# Check app health
az webapp show \
  --resource-group "react-app-rg" \
  --name "$APP_NAME" \
  --query "{state:state, url:defaultHostName, location:location}"
```

---

## Cleanup (Delete Resources)

```bash
# Delete entire resource group and all resources
az group delete \
  --name "react-app-rg" \
  --yes --no-wait

# Or delete just the app service
az webapp delete \
  --resource-group "react-app-rg" \
  --name "$APP_NAME"
```

---

## Common Issues & Solutions

### Issue: "SPA routing not working (404 errors)"
**Solution**: Ensure `web.config` is in the deployed dist folder with proper rewrite rules.

### Issue: "App Service shows default page"
**Solution**: Verify that `index.html` was deployed. Check deployment logs with `az webapp log tail`.

### Issue: "Port 80/443 connection refused"
**Solution**: Ensure runtime is configured correctly with `az webapp config show`.

### Issue: "Permission denied when deploying"
**Solution**: Check if user has sufficient permissions in the subscription:
```bash
az role assignment list --assignee <your-user-id>
```

---

## Performance Tips

1. **Enable gzip compression** (configured in web.config)
2. **Set cache headers** for static assets (configured in web.config)
3. **Scale up if needed**:
   ```bash
   az appservice plan update --name "react-app-plan" --sku "Standard@S2"
   ```
4. **Enable Application Insights** for monitoring:
   ```bash
   az monitor app-insights component create \
     --app "react-app-insights" \
     --location "eastus" \
     --resource-group "react-app-rg" \
     --application-type "web"
   ```

---

## Next Steps

1. **Test the deployment**: Visit your app URL
2. **Configure CI/CD**: Set up GitHub Actions for automatic deployment on git push
3. **Add custom domain**: Point your domain to the app service
4. **Enable monitoring**: Set up Application Insights and alerts
5. **Configure backup**: Set up automated backups if needed

---

## Useful Resources

- [Azure App Service Documentation](https://learn.microsoft.com/en-us/azure/app-service/)
- [Azure CLI Reference](https://learn.microsoft.com/cli/azure/webapp)
- [Deploy to App Service using GitHub Actions](https://github.com/Azure/webapps-deploy)
- [React SPA Deployment Best Practices](https://learn.microsoft.com/en-us/azure/app-service/app-service-web-deployment-faq)
