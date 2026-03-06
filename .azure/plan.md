# Azure App Service Deployment Plan

## Project Overview
- **Application Type**: React + Vite (SPA)
- **Framework**: React 19 with React Router
- **Build Tool**: Vite
- **Package Manager**: Yarn
- **Pages**: Home, About, Contact Us

## Deployment Strategy

### Mode: MODIFY
Adding Azure deployment capability to existing React application.

### Target: Azure App Service
- **Service**: Azure App Service (Linux-based)
- **Runtime**: Node.js (for build) + Static Web Serving
- **Deployment Method**: Azure CLI with manual steps OR Azure DevOps/GitHub Actions

### Architecture Decision
**Recipe**: Azure CLI Scripts + Manual Bicep
- Simple web app deployment
- Minimal infrastructure
- Easy to understand and modify

---

## Infrastructure Components

### Azure Resources to Create:
1. **Resource Group** - Container for all resources
2. **App Service Plan** - Linux-based, Standard tier for production
3. **App Service** - Static SPA hosting
4. **Storage Account (optional)** - For static file distribution via CDN

### Resource Details:
```
Resource Group: app-service-rg
App Service Plan: app-service-plan (Linux, Standard S1)
App Service: app-service-<unique-id>
Location: eastus (default, adjustable)
```

---

## Deployment Steps

### Phase 1: Infrastructure Setup (Azure CLI)
1. Create Resource Group
2. Create App Service Plan (Linux)
3. Create App Service
4. Configure application settings

### Phase 2: Application Build & Deploy
1. Build React app with Vite (`yarn build`)
2. Deploy dist folder to App Service
3. Configure web.config for SPA routing
4. Test deployment

### Phase 3: Configuration
1. Enable HTTPS
2. Configure custom domain (optional)
3. Set environment variables (if needed)
4. Enable continuous deployment (optional)

---

## Generated Artifacts

This plan will create:
1. `.azure/deploy.sh` - Main deployment script
2. `.azure/web.config` - IIS routing configuration for SPA
3. `.azure-commands.md` - Individual Azure CLI commands reference

---

## Estimated Costs
- **App Service Plan (Standard S1)**: ~$75/month
- **Storage Account (if CDN)**: ~$0.50-5/month
- **Bandwidth**: Pay-as-you-go

---

## Next Steps (Upon Approval)
1. Generate Azure CLI deployment script
2. Generate web.config for SPA routing
3. Provide step-by-step deployment instructions
4. Create commands reference document

---

## Status: ✅ PLAN APPROVED & EXECUTED

Generated deployment artifacts ready for use.
