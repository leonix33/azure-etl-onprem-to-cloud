# Key Vault Secret Expiration Monitoring - Quick Reference

## 🚀 Quick Start

### Option 1: Automated Setup (Recommended)
```bash
cd /Users/user/Desktop/Development/azure-etl-project
./scripts/setup-keyvault-monitoring.sh
```

This script will:
- ✅ Check prerequisites (Azure CLI, Python)
- ✅ Configure Key Vault diagnostic settings
- ✅ Install Python dependencies
- ✅ Run initial secret check
- ✅ Send data to Log Analytics
- ✅ Provide dashboard deployment instructions

### Option 2: Manual Setup

#### 1. Check Secrets Locally
```bash
# Basic check with summary
python3 scripts/check-keyvault-secrets.py --vault-name <your-vault>

# Show all secrets (not just expiring)
python3 scripts/check-keyvault-secrets.py --vault-name <your-vault> --show-all

# Export to JSON file
python3 scripts/check-keyvault-secrets.py --vault-name <your-vault> --output report.json
```

#### 2. Send to Log Analytics (for Dashboard)
```bash
# Get workspace credentials
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group <rg-name> \
  --workspace-name <workspace-name> \
  --query customerId -o tsv)

WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
  --resource-group <rg-name> \
  --workspace-name <workspace-name> \
  --query primarySharedKey -o tsv)

# Run check and send to Log Analytics
python3 scripts/check-keyvault-secrets.py \
  --vault-name <your-vault> \
  --send-to-loganalytics \
  --workspace-id "$WORKSPACE_ID" \
  --workspace-key "$WORKSPACE_KEY"
```

#### 3. Deploy Dashboard

**Option A: Terraform (Recommended)**
```bash
cd terraform
terraform apply  # Dashboard is deployed automatically!
terraform output keyvault_dashboard_url  # Get dashboard link
```

**Option B: Manual Import**
1. Go to [Azure Portal - Workbooks](https://portal.azure.com/#view/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade/~/workbooks)
2. Click **+ New**
3. Click **</>Advanced Editor** (toolbar)
4. Copy contents from `monitoring/keyvault-dashboard.json`
5. Update `fallbackResourceIds` with your workspace resource ID
6. Click **Apply** → **Done Editing** → **Save**

## 📊 Dashboard Features

| Section | Description |
|---------|-------------|
| **Expiration Overview** | Pie chart showing secrets by status (Expired, Critical, Warning, Notice, OK) |
| **Expiring Secrets** | Table of all secrets expiring within 90 days |
| **Access Patterns** | Timeline of Key Vault operations |
| **Top Accessed Secrets** | Bar chart of most frequently accessed secrets |
| **Recent Activity** | Last 100 operations with caller details |
| **Failed Attempts** | Security monitoring of failed access |
| **Availability** | Key Vault uptime monitoring |
| **Unused Secrets** | Secrets not accessed in 90+ days |

## 🚨 Alert Status Levels

| Status | Icon | Days Until Expiry | Action Required |
|--------|------|-------------------|-----------------|
| **Expired** | 🔴 | < 0 | IMMEDIATE: Rotate secret |
| **Critical** | 🟠 | ≤ 7 days | URGENT: Plan rotation |
| **Warning** | 🟡 | ≤ 30 days | Schedule rotation |
| **Notice** | 🔵 | ≤ 90 days | Review and plan |
| **OK** | 🟢 | > 90 days | No action needed |
| **No Expiry** | ⚪ | N/A | Set expiration date |

## 🔄 Automation Options

### Cron Job (Linux/macOS)
```bash
# Edit crontab
crontab -e

# Add daily check at 9 AM
0 9 * * * cd /path/to/azure-etl-project && python3 scripts/check-keyvault-secrets.py --vault-name <vault> --send-to-loganalytics --workspace-id <id> --workspace-key <key>
```

### Azure Automation Runbook
```powershell
# Create runbook with schedule
# Frequency: Daily at 09:00
python3 /scripts/check-keyvault-secrets.py \
  --vault-name $env:VAULT_NAME \
  --send-to-loganalytics \
  --workspace-id $env:WORKSPACE_ID \
  --workspace-key $env:WORKSPACE_KEY
```

### GitHub Actions
See `monitoring/README_KEYVAULT.md` for complete YAML workflow

## 🔍 Useful KQL Queries

All queries available in `monitoring/kql-queries.md` (Queries #15-27)

### Quick Queries

**Show all expiring secrets:**
```kql
KeyVaultSecretExpiry_CL
| where TimeGenerated > ago(1d)
| extend DaysUntilExpiry = datetime_diff('day', ExpirationDate_t, now())
| where DaysUntilExpiry <= 90
| order by DaysUntilExpiry asc
```

**Recent Key Vault access:**
```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where TimeGenerated > ago(1h)
| project TimeGenerated, OperationName, CallerIPAddress, ResultSignature
```

**Failed access attempts:**
```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where ResultSignature != "OK"
| summarize count() by CallerIPAddress, identity_claim_upn_s
```

## 🛠️ Terraform Resources

Key resources in `terraform/monitoring.tf`:

- `azurerm_monitor_diagnostic_setting.keyvault_diagnostics` - Log collection
- `azurerm_monitor_scheduled_query_rules_alert_v2.keyvault_secrets_expiring` - Expiry alerts
- `azurerm_monitor_metric_alert.keyvault_high_api_usage` - API monitoring
- `azurerm_monitor_metric_alert.keyvault_availability` - Uptime monitoring
- `azurerm_application_insights_workbook.keyvault_dashboard` - Dashboard deployment

Deploy/update with:
```bash
cd terraform
terraform init
terraform plan  # Review changes
terraform apply # Apply changes

# After deployment, get dashboard URL
terraform output keyvault_dashboard_url
```

The dashboard will be automatically deployed with your infrastructure! No manual JSON import needed.

## 📋 Maintenance Checklist

### Daily
- [ ] Check dashboard for expired/critical secrets
- [ ] Review failed access attempts

### Weekly  
- [ ] Run manual secret check
- [ ] Review expiring secrets (30-day window)
- [ ] Verify automation is running

### Monthly
- [ ] Review unused secrets (90+ days)
- [ ] Audit access patterns
- [ ] Clean up old/unused secrets

### Quarterly
- [ ] Review and update secret rotation policies
- [ ] Audit Key Vault access policies
- [ ] Review alert configurations

## 🐛 Common Issues

### Authentication Failed
```bash
# Solution: Login to Azure
az login
az account set --subscription <subscription-id>
```

### Access Denied to Key Vault
```bash
# Solution: Grant yourself access
az keyvault set-policy \
  --name <vault-name> \
  --upn <your-email> \
  --secret-permissions get list
```

### Dashboard Shows No Data
```bash
# Solution 1: Run the Python script to populate data
python3 scripts/check-keyvault-secrets.py --vault-name <vault> --send-to-loganalytics ...

# Solution 2: Wait 5-10 minutes for Log Analytics ingestion

# Solution 3: Check the custom log table exists
# Go to Log Analytics → Logs → Run:
KeyVaultSecretExpiry_CL | take 10
```

### Python Dependencies Not Found
```bash
# Solution: Install required packages
pip3 install azure-identity azure-keyvault-secrets tabulate requests
```

## 📁 Project Structure

```
azure-etl-project/
├── terraform/
│   ├── monitoring.tf              ← Key Vault alerts & diagnostics
│   └── keyvault.tf                ← Key Vault configuration
├── monitoring/
│   ├── keyvault-dashboard.json    ← Azure Workbook JSON
│   ├── kql-queries.md             ← All KQL queries
│   ├── README_KEYVAULT.md         ← Full documentation
│   └── QUICKSTART_KEYVAULT.md     ← This file
└── scripts/
    ├── check-keyvault-secrets.py  ← Main monitoring script
    └── setup-keyvault-monitoring.sh ← Automated setup
```

## 🔗 Quick Links

- [Full Documentation](./README_KEYVAULT.md)
- [KQL Queries](./kql-queries.md#key-vault-secret-management-and-expiration)
- [Azure Portal - Workbooks](https://portal.azure.com/#view/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade/~/workbooks)
- [Azure Portal - Key Vaults](https://portal.azure.com/#view/HubsExtension/BrowseResource/resourceType/Microsoft.KeyVault%2Fvaults)
- [Azure Portal - Log Analytics](https://portal.azure.com/#view/HubsExtension/BrowseResource/resourceType/Microsoft.OperationalInsights%2Fworkspaces)

## 💡 Pro Tips

1. **Set expiration dates on all secrets** - Use `--expires` parameter
2. **Automate secret rotation** - Use Azure Key Vault rotation policies
3. **Monitor unused secrets** - Remove secrets not accessed in 90+ days
4. **Use managed identities** - Avoid storing credentials in code
5. **Review audit logs regularly** - Monitor for suspicious activity
6. **Test rotation process** - Ensure applications handle secret updates
7. **Document secret purposes** - Use tags or naming conventions
8. **Schedule regular reviews** - Weekly dashboard checks recommended

---

**Need Help?** See [README_KEYVAULT.md](./README_KEYVAULT.md) for detailed documentation
