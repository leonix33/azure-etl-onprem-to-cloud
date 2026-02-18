# Key Vault Dashboard Showcase Setup

## Overview

Your Key Vault monitoring setup is now configured to demonstrate **all status levels** on the dashboard with real secrets having different expiration dates.

## 📊 Dashboard Status Legend

Your secrets are configured to show the complete range of expiration statuses:

| Secret Name | Status | Days Until Expiry | Expiration Date | Color |
|-------------|--------|-------------------|-----------------|-------|
| `sql-connection-string` | 🔴 **EXPIRED** | -5 days (overdue) | Feb 12, 2026 | Red |
| `vm-admin-password` | 🟠 **CRITICAL** | 3 days | Feb 20, 2026 | Orange |
| `ai-search-admin-key` | 🟡 **WARNING** | 15 days | Mar 4, 2026 | Yellow |
| `openai-api-key` | 🔵 **NOTICE** | 60 days | Apr 18, 2026 | Blue |
| `storage-connection-string` | 🟢 **OK** | 120 days | Jun 17, 2026 | Green |
| `demo-secret-no-expiry` | ⚪ **NO EXPIRY** | Never | - | Gray |

## 🏗️ Architecture Components

### 1. Log Analytics Workspace ✅
**Already configured and essential!**

```
azurerm_log_analytics_workspace.etl_logs
├── Stores Key Vault diagnostic logs (audit events)
├── Receives custom logs from Python script (KeyVaultSecretExpiry_CL)
├── Powers all dashboard queries
└── Enables scheduled query alerts
```

### 2. Key Vault Diagnostic Settings ✅
```
azurerm_monitor_diagnostic_setting.keyvault_diagnostics
├── Captures AuditEvent logs (who accessed what)
├── Captures AzurePolicyEvaluationDetails
├── Sends all metrics (API usage, availability)
└── Streams to Log Analytics workspace
```

### 3. Monitoring Script
```bash
scripts/check-keyvault-secrets.py
├── Connects to Key Vault via Azure SDK
├── Lists all secrets and their properties
├── Calculates days until expiration
├── Determines status (Expired, Critical, Warning, Notice, OK)
└── Sends data to Log Analytics (KeyVaultSecretExpiry_CL table)
```

### 4. Azure Workbook Dashboard ✅
```
azurerm_application_insights_workbook.keyvault_dashboard
├── Automatically deployed via Terraform
├── Queries Log Analytics for data
├── Visual charts: Pie chart, tables, timelines
└── Real-time secret expiration tracking
```

## 🚀 Deployment Steps

### 1. Deploy Infrastructure
```bash
cd /Users/user/Desktop/Development/azure-etl-project/terraform

# Review what will be created
terraform plan

# Deploy everything (including dashboard)
terraform apply

# Get the dashboard URL
terraform output keyvault_dashboard_url
```

### 2. Populate Dashboard Data
```bash
cd /Users/user/Desktop/Development/azure-etl-project

# Get Log Analytics credentials
export WORKSPACE_ID=$(terraform -chdir=terraform output -raw log_analytics_workspace_id | cut -d'/' -f9)
export VAULT_NAME=$(terraform -chdir=terraform output -raw key_vault_name)

# Get workspace key
export WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
  --resource-group $(terraform -chdir=terraform output -raw resource_group_name) \
  --workspace-name $(terraform -chdir=terraform output -raw log_analytics_workspace_name) \
  --query primarySharedKey -o tsv)

# Run the monitoring script
python3 scripts/check-keyvault-secrets.py \
  --vault-name "$VAULT_NAME" \
  --send-to-loganalytics \
  --workspace-id "$WORKSPACE_ID" \
  --workspace-key "$WORKSPACE_KEY" \
  --show-all
```

### 3. View Dashboard
```bash
# Open the dashboard URL (from terraform output)
open $(terraform -chdir=terraform output -raw keyvault_dashboard_url)

# Or navigate manually:
# Azure Portal → Monitor → Workbooks → "Key Vault Security Dashboard"
```

## 📈 What You'll See on the Dashboard

### Expiration Overview (Pie Chart)
- 🔴 Expired: 1 secret (sql-connection-string)
- 🟠 Critical (≤7 days): 1 secret (vm-admin-password)
- 🟡 Warning (≤30 days): 1 secret (ai-search-admin-key)
- 🔵 Notice (≤90 days): 1 secret (openai-api-key)
- 🟢 OK (>90 days): 1 secret (storage-connection-string)
- ⚪ No Expiry: 1 secret (demo-secret-no-expiry)

### Expiring Secrets Table
Shows all secrets expiring within 90 days, sorted by urgency.

### Access Patterns Timeline
Real-time view of who's accessing which secrets.

### Security Monitoring
- Failed access attempts
- Unusual access patterns
- Secrets not accessed in 90+ days

### Key Vault Metrics
- API usage trends
- Availability percentage
- Request latency

## 🔔 Alerts Configuration

Your setup includes automatic alerts:

| Alert | Condition | Severity | Action |
|-------|-----------|----------|--------|
| Secrets Expiring (30d) | Any secret expires ≤30 days | Warning | Email |
| High API Usage | >1000 requests in 15 min | Warning | Email |
| Availability Drop | Availability <99% | Critical | Email |

## 🔄 Maintenance

### Daily
```bash
# Check for expired/critical secrets
python3 scripts/check-keyvault-secrets.py --vault-name "$VAULT_NAME"
```

### Weekly
```bash
# Update Log Analytics with latest data
python3 scripts/check-keyvault-secrets.py \
  --vault-name "$VAULT_NAME" \
  --send-to-loganalytics \
  --workspace-id "$WORKSPACE_ID" \
  --workspace-key "$WORKSPACE_KEY"
```

### Automate with Cron
```bash
# Add to crontab (daily at 9 AM)
0 9 * * * cd /Users/user/Desktop/Development/azure-etl-project && \
  python3 scripts/check-keyvault-secrets.py \
  --vault-name YOUR_VAULT \
  --send-to-loganalytics \
  --workspace-id YOUR_ID \
  --workspace-key YOUR_KEY
```

## 🎯 Why Log Analytics is Essential

Without Log Analytics, you would **NOT** have:
- ❌ Dashboard visualizations (no data source)
- ❌ Historical tracking (no log retention)
- ❌ Scheduled alerts (no query engine)
- ❌ Security audit trail (no access logs)
- ❌ Custom metrics from Python script

With Log Analytics, you **DO** have:
- ✅ 30-day log retention (configurable)
- ✅ PowerfulKQL query engine
- ✅ Real-time and historical analysis
- ✅ Integration with Azure Monitor alerts
- ✅ Custom log tables (KeyVaultSecretExpiry_CL)

## 📚 Related Documentation

- [Full Documentation](./README_KEYVAULT.md) - Complete setup guide
- [Quick Reference](./QUICKSTART_KEYVAULT.md) - Commands and cheat sheet
- [Architecture Diagrams](./ARCHITECTURE_KEYVAULT.md) - Visual system design
- [KQL Queries](./kql-queries.md) - All monitoring queries

## 🎨 Customization

### Change Expiration Dates
Edit [keyvault.tf](../terraform/keyvault.tf) and adjust `expiration_date` values:
```terraform
resource "azurerm_key_vault_secret" "example" {
  # ...
  expiration_date = "2026-12-31T23:59:59Z"  # ISO 8601 format
}
```

### Adjust Alert Thresholds
Edit [monitoring.tf](../terraform/monitoring.tf) to change alert conditions:
```terraform
# Alert 7 days before expiry instead of 30
where DaysUntilExpiry <= 7 and DaysUntilExpiry >= 0
```

### Add More Secrets
```terraform
resource "azurerm_key_vault_secret" "new_secret" {
  name            = "my-new-secret"
  value           = "secret-value"
  key_vault_id    = azurerm_key_vault.etl_kv.id
  expiration_date = "2027-01-01T23:59:59Z"
  
  depends_on = [azurerm_key_vault_access_policy.terraform_policy]
}
```

## 💡 Pro Tips

1. **Always set expiration dates** - Secrets without expiration create security risks
2. **Use shorter dates for demos** - Makes the dashboard more interesting
3. **Test rotation procedures** - Have a plan before secrets actually expire
4. **Monitor unused secrets** - Remove secrets not accessed in 90+ days
5. **Review access patterns** - Look for unusual activity or unauthorized attempts

---

**Summary:** Your Key Vault monitoring is a complete, production-ready solution with automated deployment, real-time dashboards, and proactive alerting. Log Analytics is the central hub that makes everything work together!
