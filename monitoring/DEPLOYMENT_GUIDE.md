# Key Vault Dashboard - Complete Deployment Guide

## 🎯 Overview

This guide walks you through deploying the complete Key Vault monitoring solution with the interactive Azure Workbook dashboard.

## 📋 What Gets Deployed

### Infrastructure (Terraform)
```
✅ Log Analytics Workspace          → Data storage & query engine
✅ Key Vault + Secrets (6 secrets)  → With various expiration dates
✅ Diagnostic Settings              → Streams Key Vault logs
✅ Alert Rules (3 alerts)           → Email notifications
✅ Action Group                     → Email/SMS alerting
✅ Azure Workbook Dashboard         → Interactive visualization
```

### Secrets with Expiration Demo
```
Secret Name                   | Status      | Days  | Expiration Date
------------------------------|-------------|-------|------------------
sql-connection-string         | 🔴 EXPIRED  | -5    | Feb 12, 2026
vm-admin-password             | 🟠 CRITICAL | 3     | Feb 20, 2026
ai-search-admin-key           | 🟡 WARNING  | 15    | Mar 4, 2026
openai-api-key                | 🔵 NOTICE   | 60    | Apr 18, 2026
storage-connection-string     | 🟢 OK       | 120   | Jun 17, 2026
demo-secret-no-expiry         | ⚪ NO EXPIRY| Never | -
```

## 🚀 Deployment Steps

### Step 1: Pre-Deployment Check

```bash
cd /Users/user/Desktop/Development/azure-etl-project/terraform

# Login to Azure
az login
az account show  # Verify correct subscription

# Initialize Terraform (if not done)
terraform init

# Validate configuration
terraform validate

# Preview what will be created
terraform plan
```

**Review the plan output carefully!** Look for:
- ✅ Key Vault resource
- ✅ Log Analytics workspace
- ✅ Diagnostic settings
- ✅ Azure Workbook (keyvault_dashboard)
- ✅ 6 secrets with expiration dates
- ✅ 3 alert rules

### Step 2: Deploy Infrastructure

```bash
# Deploy everything
terraform apply

# When prompted, review the plan and type 'yes' to continue
```

**Deployment time:** ~5-10 minutes

**What happens:**
1. Creates resource group
2. Creates Log Analytics workspace
3. Creates Key Vault with 6 secrets (different expiration dates)
4. Configures diagnostic settings (logs flow to Log Analytics)
5. Creates alert rules for expiring secrets
6. **Deploys Azure Workbook dashboard** (automatically!)
7. Sets up action group for email alerts

### Step 3: Get Resource Information

```bash
# Get all important outputs
terraform output

# Get specific values
export VAULT_NAME=$(terraform output -raw key_vault_name)
export RG_NAME=$(terraform output -raw resource_group_name)
export WORKSPACE_NAME=$(terraform output -raw log_analytics_workspace_name)
export DASHBOARD_URL=$(terraform output -raw keyvault_dashboard_url)

echo "Key Vault: $VAULT_NAME"
echo "Resource Group: $RG_NAME"
echo "Dashboard URL: $DASHBOARD_URL"
```

### Step 4: Populate Dashboard Data

The dashboard needs data to display. Run the Python monitoring script:

```bash
cd /Users/user/Desktop/Development/azure-etl-project

# Install Python dependencies (one-time)
pip3 install azure-identity azure-keyvault-secrets tabulate requests

# Get Log Analytics workspace ID (just the GUID)
export WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group "$RG_NAME" \
  --workspace-name "$WORKSPACE_NAME" \
  --query customerId -o tsv)

# Get Log Analytics primary key
export WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
  --resource-group "$RG_NAME" \
  --workspace-name "$WORKSPACE_NAME" \
  --query primarySharedKey -o tsv)

# Run the monitoring script to populate data
python3 scripts/check-keyvault-secrets.py \
  --vault-name "$VAULT_NAME" \
  --send-to-loganalytics \
  --workspace-id "$WORKSPACE_ID" \
  --workspace-key "$WORKSPACE_KEY" \
  --show-all
```

**Expected output:**
```
Checking secrets in Key Vault: kv-etl-abc123
Found 6 secrets

Secret Expiration Status:
┌─────────────────────────────┬────────────┬──────────────────────┬─────────────┐
│ Secret Name                 │ Status     │ Expiration Date      │ Days Left   │
├─────────────────────────────┼────────────┼──────────────────────┼─────────────┤
│ sql-connection-string       │ 🔴 EXPIRED │ 2026-02-12 23:59:59  │ -5 days     │
│ vm-admin-password           │ 🟠 CRITICAL│ 2026-02-20 23:59:59  │ 3 days      │
│ ai-search-admin-key         │ 🟡 WARNING │ 2026-03-04 23:59:59  │ 15 days     │
│ openai-api-key              │ 🔵 NOTICE  │ 2026-04-18 23:59:59  │ 60 days     │
│ storage-connection-string   │ 🟢 OK      │ 2026-06-17 23:59:59  │ 120 days    │
│ demo-secret-no-expiry       │ ⚪ NO EXP  │ Never                │ Never       │
└─────────────────────────────┴────────────┴──────────────────────┴─────────────┘

✅ Successfully sent data to Log Analytics
   Table: KeyVaultSecretExpiry_CL
   Records: 6
```

### Step 5: Access the Dashboard

**Option 1: Direct URL (Easiest)**
```bash
# Open in browser
open "$DASHBOARD_URL"

# Or on Linux
xdg-open "$DASHBOARD_URL"
```

**Option 2: Azure Portal Navigation**
1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Monitor** → **Workbooks**
3. Look for **"Key Vault Security Dashboard"**
4. Click to open

**Option 3: From Resource Group**
1. Go to your Resource Group (from `terraform output`)
2. Filter resources by type: **Workbook**
3. Click on **"Key Vault Security Dashboard"**

### Step 6: Verify Dashboard is Working

Wait 5-10 minutes for Log Analytics to ingest the data, then check:

**Dashboard Sections You Should See:**

1. **🔐 Secret Expiration Overview**
   - Pie chart showing 6 secrets across different statuses
   - Color-coded by severity

2. **📊 Expiring Secrets Table**
   - Lists all secrets expiring ≤90 days
   - Should show 4 secrets (expired, critical, warning, notice)

3. **📈 Access Patterns Timeline**
   - Shows Key Vault operations over time
   - Updates as secrets are accessed

4. **🔝 Top Accessed Secrets**
   - Bar chart of most frequently used secrets

5. **🔍 Recent Activity**
   - Last 100 Key Vault operations

6. **🚨 Failed Access Attempts**
   - Security monitoring (should be empty initially)

7. **⚡ Key Vault Availability**
   - Uptime metrics (should be ~100%)

8. **💤 Unused Secrets**
   - Secrets not accessed in 90+ days

## 🔔 Alert Configuration

Your deployment includes 3 automatic alerts:

### Alert 1: Secrets Expiring Soon
- **Trigger:** Secrets expiring ≤30 days
- **Check:** Daily
- **Action:** Email to `var.alert_email_address`
- **Status:** Active

### Alert 2: High API Usage
- **Trigger:** >1000 Key Vault API calls in 15 minutes
- **Check:** Every 5 minutes
- **Action:** Email notification
- **Status:** Active

### Alert 3: Availability Drop
- **Trigger:** Key Vault availability <99%
- **Check:** Every 5 minutes
- **Action:** Email notification (critical)
- **Status:** Active

**To verify alerts:**
```bash
az monitor alert list \
  --resource-group "$RG_NAME" \
  --query "[?contains(name, 'keyvault')].{Name:name, Status:enabled}" \
  --output table
```

## 🔄 Automation Setup (Optional but Recommended)

### Option A: Cron Job (macOS/Linux)

```bash
# Edit crontab
crontab -e

# Add this line (runs daily at 9 AM)
0 9 * * * cd /Users/user/Desktop/Development/azure-etl-project && \
  /usr/local/bin/python3 scripts/check-keyvault-secrets.py \
  --vault-name $(terraform -chdir=terraform output -raw key_vault_name) \
  --send-to-loganalytics \
  --workspace-id YOUR_WORKSPACE_ID \
  --workspace-key YOUR_WORKSPACE_KEY \
  >> /tmp/keyvault-check.log 2>&1
```

### Option B: GitHub Actions

Create `.github/workflows/keyvault-monitoring.yml`:

```yaml
name: Key Vault Secret Monitor

on:
  schedule:
    - cron: '0 9 * * *'  # Daily at 9 AM UTC
  workflow_dispatch:      # Manual trigger

jobs:
  check-secrets:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Install Dependencies
        run: pip install azure-identity azure-keyvault-secrets tabulate requests
      
      - name: Check Key Vault Secrets
        env:
          VAULT_NAME: ${{ secrets.VAULT_NAME }}
          WORKSPACE_ID: ${{ secrets.WORKSPACE_ID }}
          WORKSPACE_KEY: ${{ secrets.WORKSPACE_KEY }}
        run: |
          python3 scripts/check-keyvault-secrets.py \
            --vault-name "$VAULT_NAME" \
            --send-to-loganalytics \
            --workspace-id "$WORKSPACE_ID" \
            --workspace-key "$WORKSPACE_KEY"
```

### Option C: Azure Automation Runbook

See [README_KEYVAULT.md](./README_KEYVAULT.md) for complete runbook setup.

## 📊 Dashboard Usage Guide

### Time Range Selection
- Use the time picker at the top to adjust the view
- Default: Last 30 days
- Options: 1 hour, 1 day, 7 days, 30 days, 90 days

### Filtering by Key Vault
- If you have multiple Key Vaults, use the dropdown filter
- Default: Shows all Key Vaults

### Refresh Data
- Dashboard auto-refreshes based on your settings
- Manual refresh: Click the refresh icon (top right)

### Export Data
- Click **Export** → **Excel** to download data
- Click **Export** → **PDF** for reports

### Share Dashboard
- Click **Share** → **Copy Link** to share with team
- Set permissions: Viewer or Editor

## 🔍 KQL Queries (Direct Log Analytics)

If you want to query data directly:

1. Go to **Log Analytics Workspace** → **Logs**
2. Run these queries:

**Show all secrets with expiration:**
```kql
KeyVaultSecretExpiry_CL
| where TimeGenerated > ago(1d)
| where isnotempty(ExpirationDate_t)
| extend DaysUntilExpiry = datetime_diff('day', ExpirationDate_t, now())
| project SecretName_s, DaysUntilExpiry, ExpirationDate_t, Status_s
| order by DaysUntilExpiry asc
```

**Show recent Key Vault access:**
```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where TimeGenerated > ago(1h)
| where OperationName in ("SecretGet", "SecretList", "SecretSet")
| project TimeGenerated, OperationName, CallerIPAddress, identity_claim_upn_s
| order by TimeGenerated desc
```

**Show failed access attempts:**
```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where ResultSignature != "OK"
| summarize FailedAttempts=count() by CallerIPAddress, identity_claim_upn_s, OperationName
| order by FailedAttempts desc
```

More queries: [kql-queries.md](./kql-queries.md#key-vault-secret-management-and-expiration)

## 🛠️ Troubleshooting

### Issue 1: Dashboard Shows "No Data"

**Cause:** Log Analytics hasn't received data yet

**Solution:**
```bash
# 1. Verify Python script ran successfully
python3 scripts/check-keyvault-secrets.py \
  --vault-name "$VAULT_NAME" \
  --send-to-loganalytics \
  --workspace-id "$WORKSPACE_ID" \
  --workspace-key "$WORKSPACE_KEY"

# 2. Check if custom log table exists (wait 5-10 min after first run)
az monitor log-analytics query \
  --workspace "$WORKSPACE_ID" \
  --analytics-query "KeyVaultSecretExpiry_CL | take 1"

# 3. Check diagnostic settings are enabled
az monitor diagnostic-settings list \
  --resource "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RG_NAME/providers/Microsoft.KeyVault/vaults/$VAULT_NAME"
```

### Issue 2: Python Script Fails (Authentication)

**Cause:** Not logged in to Azure

**Solution:**
```bash
az login
az account set --subscription YOUR_SUBSCRIPTION_ID
```

### Issue 3: Access Denied to Key Vault

**Cause:** No permissions on Key Vault

**Solution:**
```bash
az keyvault set-policy \
  --name "$VAULT_NAME" \
  --upn YOUR_EMAIL@domain.com \
  --secret-permissions get list
```

### Issue 4: Dashboard URL Not Working

**Cause:** Workbook not deployed or wrong URL format

**Solution:**
```bash
# List all workbooks
az monitor app-insights workbook list \
  --resource-group "$RG_NAME" \
  --output table

# Get correct URL
terraform output keyvault_dashboard_url
```

### Issue 5: No Email Alerts Received

**Cause:** Action group not configured with your email

**Solution:**
```bash
# Update variables.tf with your email
# Then redeploy
cd terraform
terraform apply -var="alert_email_address=your-email@example.com"
```

## 📋 Maintenance Checklist

### Daily
- [ ] Review dashboard for critical/expired secrets
- [ ] Check for failed access attempts

### Weekly
- [ ] Run manual secret check
- [ ] Verify automation is working
- [ ] Review upcoming expirations (30-day window)

### Monthly
- [ ] Review unused secrets (90+ days)
- [ ] Audit access patterns
- [ ] Clean up old secrets
- [ ] Verify alerts are working

### Quarterly
- [ ] Update secret rotation policies
- [ ] Audit Key Vault access policies
- [ ] Review alert thresholds
- [ ] Update dashboard as needed

## 🎨 Customization

### Change Expiration Dates
Edit [terraform/keyvault.tf](../terraform/keyvault.tf):
```terraform
resource "azurerm_key_vault_secret" "example" {
  expiration_date = "2027-12-31T23:59:59Z"  # Change date
}
```

### Adjust Alert Thresholds
Edit [terraform/monitoring.tf](../terraform/monitoring.tf):
```terraform
# Change from 30 days to 7 days
where DaysUntilExpiry <= 7 and DaysUntilExpiry >= 0
```

### Add More Dashboard Sections
Edit [monitoring/keyvault-dashboard.json](./keyvault-dashboard.json) and redeploy.

## 🧹 Cleanup

To remove all resources:

```bash
cd terraform
terraform destroy

# Confirm by typing 'yes'
```

**Warning:** This will delete:
- Key Vault and all secrets
- Log Analytics workspace (all logs)
- Dashboard
- All alerts

## 📚 Additional Resources

- [Full Documentation](./README_KEYVAULT.md)
- [Quick Reference](./QUICKSTART_KEYVAULT.md)
- [Architecture Diagrams](./ARCHITECTURE_KEYVAULT.md)
- [Dashboard Showcase](./DASHBOARD_SHOWCASE.md)
- [KQL Queries](./kql-queries.md)

## 🎯 Success Criteria

Your deployment is successful when:

✅ All Terraform resources deployed without errors  
✅ Dashboard accessible via URL or Azure Portal  
✅ Dashboard shows 6 secrets with different statuses  
✅ Pie chart displays color-coded expiration levels  
✅ Python script runs successfully  
✅ Custom log table (KeyVaultSecretExpiry_CL) has data  
✅ Email alerts configured and active  
✅ KQL queries return results in Log Analytics  

## 🆘 Getting Help

- **Terraform Errors:** Run `terraform plan` to see detailed error messages
- **Dashboard Issues:** Check Log Analytics has data: `KeyVaultSecretExpiry_CL | take 10`
- **Python Script Issues:** Run with `--verbose` flag for detailed output
- **Azure Errors:** Check Activity Log in Azure Portal

---

**You're all set!** Your Key Vault monitoring solution is production-ready with automated deployment, real-time dashboards, and proactive alerting. 🚀
