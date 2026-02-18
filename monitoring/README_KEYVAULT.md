# Azure Key Vault Secret Monitoring & Expiration Dashboard

Complete solution for monitoring Azure Key Vault secrets with expiration tracking, security audit trails, and alerting.

## 📋 Overview

This monitoring solution provides:

- **🔐 Secret Expiration Tracking**: Monitor secrets expiring in 7, 30, and 90 days
- **📊 Interactive Dashboard**: Azure Workbook with visual secret status
- **🚨 Automated Alerts**: Email notifications for expiring/expired secrets
- **📈 Access Audit Trail**: Track who accessed which secrets and when
- **🔍 Security Monitoring**: Failed access attempts and unusual patterns
- **⚡ Automated Checks**: Python script for scheduled secret monitoring

## 🏗️ Architecture

```
┌─────────────────────┐
│   Azure Key Vault   │
│    - Secrets        │
└──────────┬──────────┘
           │
           │ Diagnostic Logs
           ▼
┌──────────────────────────┐
│  Log Analytics Workspace │
│  - Audit Events          │
│  - Metrics               │
│  - Custom Logs           │
└──────────┬───────────────┘
           │
           ├──────────────────────┐
           │                      │
           ▼                      ▼
┌─────────────────────┐  ┌──────────────────┐
│  Azure Workbook     │  │  Alert Rules     │
│  (Dashboard)        │  │  - Email/SMS     │
│  - Visual Status    │  │  - Action Groups │
│  - Expiry Timeline  │  └──────────────────┘
└─────────────────────┘
           ▲
           │
┌──────────┴──────────────┐
│  Python Script          │
│  check-keyvault-secrets │
│  - Query Key Vault      │
│  - Send to Log Analytics│
└─────────────────────────┘
```

## 🚀 Quick Start

### 1. Deploy Infrastructure with Terraform

The Terraform configuration in `terraform/monitoring.tf` includes:
- Key Vault diagnostic settings
- Log Analytics workspace integration
- Metric alerts for high API usage and availability
- Scheduled query alerts for expiring secrets

```bash
cd terraform
terraform init
terraform apply
```

### 2. Install Python Dependencies

```bash
pip install azure-identity azure-keyvault-secrets tabulate requests
```

### 3. Run Secret Expiration Check

```bash
# Basic check
python scripts/check-keyvault-secrets.py --vault-name your-keyvault-name

# Show all secrets (not just expiring)
python scripts/check-keyvault-secrets.py --vault-name your-keyvault-name --show-all

# Export to JSON
python scripts/check-keyvault-secrets.py --vault-name your-keyvault-name --output report.json
```

### 4. Send Data to Log Analytics (for Dashboard)

Get your Log Analytics Workspace ID and Key:

```bash
# Get Workspace ID
az monitor log-analytics workspace show \
  --resource-group <your-rg> \
  --workspace-name <workspace-name> \
  --query customerId -o tsv

# Get Workspace Key
az monitor log-analytics workspace get-shared-keys \
  --resource-group <your-rg> \
  --workspace-name <workspace-name> \
  --query primarySharedKey -o tsv
```

Then send data:

```bash
python scripts/check-keyvault-secrets.py \
  --vault-name your-keyvault-name \
  --send-to-loganalytics \
  --workspace-id YOUR_WORKSPACE_ID \
  --workspace-key YOUR_WORKSPACE_KEY
```

### 5. Deploy the Dashboard

1. Go to **Azure Portal** → **Monitor** → **Workbooks**
2. Click **+ New**
3. Click **</> Advanced Editor** (top toolbar)
4. Paste the contents of `monitoring/keyvault-dashboard.json`
5. Update the `fallbackResourceIds` at the bottom with your workspace resource ID:
   ```
   /subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RG/providers/Microsoft.OperationalInsights/workspaces/YOUR_WORKSPACE
   ```
6. Click **Apply** and then **Done Editing**
7. Click **Save** and give it a title (e.g., "Key Vault Security Dashboard")

## 📊 Dashboard Features

### Expiration Overview
- **Pie Chart**: Visual breakdown of secrets by status
- **Tile Summary**: Count of expired, critical, warning, and notice secrets
- **Detailed Table**: All expiring secrets with color-coded status

### Access Patterns
- **Operations Timeline**: SecretGet, SecretSet, SecretDelete over time
- **Top Accessed Secrets**: Bar chart of most frequently accessed secrets
- **Recent Activity**: Last 100 Key Vault operations with caller details

### Security & Alerts
- **Failed Access Attempts**: Unauthorized or failed operations
- **Key Vault Availability**: Uptime monitoring
- **Unused Secrets**: Secrets not accessed in 90+ days

## 🔍 KQL Queries

All KQL queries are documented in [`monitoring/kql-queries.md`](./monitoring/kql-queries.md)

Key queries include:
- **Query #15-27**: Key Vault specific monitoring
- Secret expiration tracking
- Access audit trails
- Security analysis
- Performance metrics

### Example Query - Secrets Expiring in 30 Days

```kql
KeyVaultSecretExpiry_CL
| where TimeGenerated > ago(1d)
| extend DaysUntilExpiry = datetime_diff('day', ExpirationDate_t, now())
| where DaysUntilExpiry <= 30 and DaysUntilExpiry >= 0
| project 
    SecretName = SecretName_s,
    ExpirationDate = ExpirationDate_t,
    DaysRemaining = DaysUntilExpiry
| order by DaysRemaining asc
```

## 🚨 Alerts Configuration

### Terraform Alerts

The following alerts are configured in `terraform/monitoring.tf`:

1. **Secrets Expiring Soon (30 days)**
   - Severity: 2 (Warning)
   - Evaluation: Daily
   - Action: Email notification

2. **High API Usage**
   - Threshold: >1000 requests in 15 minutes
   - Severity: 3 (Informational)
   - Evaluation: Every 5 minutes

3. **Availability Issues**
   - Threshold: <99% availability
   - Severity: 1 (Critical)
   - Action: Immediate email notification

### Customizing Alerts

Edit `terraform/monitoring.tf` to adjust:
- Thresholds
- Evaluation frequency
- Notification channels
- Severity levels

## 🤖 Automation

### Scheduled Checks with Azure Automation

Create an Azure Automation Runbook:

```powershell
# Import modules
Import-Module Az.KeyVault
Import-Module Az.OperationalInsights

# Run Python script
python /scripts/check-keyvault-secrets.py \
  --vault-name $VaultName \
  --send-to-loganalytics \
  --workspace-id $WorkspaceId \
  --workspace-key $WorkspaceKey
```

Schedule it to run daily or weekly.

### GitHub Actions

```yaml
name: Check Key Vault Secrets

on:
  schedule:
    - cron: '0 9 * * 1'  # Every Monday at 9 AM
  workflow_dispatch:

jobs:
  check-secrets:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Install Python dependencies
        run: pip install azure-identity azure-keyvault-secrets tabulate requests
      
      - name: Check Key Vault Secrets
        run: |
          python scripts/check-keyvault-secrets.py \
            --vault-name ${{ secrets.VAULT_NAME }} \
            --send-to-loganalytics \
            --workspace-id ${{ secrets.WORKSPACE_ID }} \
            --workspace-key ${{ secrets.WORKSPACE_KEY }}
```

## 📧 Alert Notifications

### Email Configuration

Alerts are sent via Azure Monitor Action Groups. Configure recipients in `terraform/monitoring.tf`:

```terraform
resource "azurerm_monitor_action_group" "etl_alerts" {
  email_receiver {
    name          = "Admin Email"
    email_address = var.alert_email_address
  }
  
  # Add more receivers
  email_receiver {
    name          = "Security Team"
    email_address = "security@example.com"
  }
  
  # SMS notification
  sms_receiver {
    name         = "On-Call"
    country_code = "1"
    phone_number = "5555551234"
  }
}
```

## 🔒 Security Best Practices

1. **Set Expiration Dates**: Always set expiration dates on secrets
   ```bash
   az keyvault secret set \
     --vault-name mykeyvault \
     --name mysecret \
     --value "secret-value" \
     --expires "2026-12-31T23:59:59Z"
   ```

2. **Rotate Secrets**: Implement secret rotation policies
   - Use Azure Key Vault automatic rotation
   - Update secrets before expiration
   - Test rotation process in non-production

3. **Monitor Access**: Review access patterns regularly
   - Investigate unusual access patterns
   - Remove unused secrets
   - Audit failed access attempts

4. **Least Privilege**: Use managed identities and access policies
   - Grant minimum required permissions
   - Use separate key vaults for different environments
   - Implement network restrictions

## 📝 Maintenance

### Regular Tasks

- **Weekly**: Review expiring secrets dashboard
- **Monthly**: Check unused secrets (90+ days)
- **Quarterly**: Audit access patterns and permissions
- **Annually**: Review and update secret rotation policies

### Updating Secrets

When rotating secrets:

1. Create new secret version
2. Update application to use new version
3. Verify application functionality
4. Disable old secret version
5. Schedule old version deletion (after grace period)

## 🐛 Troubleshooting

### Python Script Issues

**Error: Authentication failed**
```bash
# Login with Azure CLI
az login

# Set subscription
az account set --subscription YOUR_SUBSCRIPTION_ID
```

**Error: Access denied to Key Vault**
```bash
# Grant yourself access
az keyvault set-policy \
  --name your-keyvault \
  --upn your-email@example.com \
  --secret-permissions get list
```

### Dashboard Not Showing Data

1. **Check diagnostic settings are enabled**
   ```bash
   az monitor diagnostic-settings list \
     --resource /subscriptions/.../providers/Microsoft.KeyVault/vaults/your-vault
   ```

2. **Verify Log Analytics connection**
   - Ensure secrets check script ran successfully
   - Check for `KeyVaultSecretExpiry_CL` table in Log Analytics

3. **Update timerange parameter**
   - Dashboard may need data from longer time period
   - Run the Python script to populate initial data

### Alerts Not Firing

1. **Check alert rule status**
   ```bash
   az monitor metrics alert show \
     --name keyvault-secrets-expiring-30d \
     --resource-group your-rg
   ```

2. **Verify action group**
   - Check email address is correct
   - Look for email in spam folder
   - Verify email is confirmed

## 📚 Additional Resources

- [Azure Key Vault Documentation](https://docs.microsoft.com/azure/key-vault/)
- [Log Analytics Query Language](https://docs.microsoft.com/azure/azure-monitor/logs/log-query-overview)
- [Azure Monitor Workbooks](https://docs.microsoft.com/azure/azure-monitor/visualize/workbooks-overview)
- [Secret Rotation Best Practices](https://docs.microsoft.com/azure/key-vault/secrets/rotation-best-practices)

## 📄 Files in This Solution

```
azure-etl-project/
├── terraform/
│   ├── monitoring.tf          # Key Vault diagnostics and alerts
│   └── keyvault.tf            # Key Vault configuration
├── monitoring/
│   ├── kql-queries.md         # All KQL queries (#15-27 for Key Vault)
│   ├── keyvault-dashboard.json # Azure Workbook JSON
│   └── README_KEYVAULT.md     # This file
└── scripts/
    └── check-keyvault-secrets.py # Python monitoring script
```

## 🤝 Contributing

To add new features:
1. Add KQL queries to `kql-queries.md`
2. Update dashboard JSON with new visualizations
3. Extend Python script for additional checks
4. Update Terraform for new alerts

## 📞 Support

For issues or questions:
- Review troubleshooting section above
- Check Azure Monitor logs
- Review Key Vault audit logs
- Consult Azure documentation

---

**Last Updated**: February 2026
