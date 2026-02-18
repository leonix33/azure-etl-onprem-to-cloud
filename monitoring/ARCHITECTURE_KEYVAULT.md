# Key Vault Secret Monitoring Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Azure Key Vault                                  │
│  ┌──────────────────────────────────────────────────────────────┐      │
│  │  Secrets:                                                     │      │
│  │  • vm-admin-password        (Expires: 2026-06-01) ⚠️          │      │
│  │  • storage-connection-string (Expires: 2026-12-31) ✅         │      │
│  │  • sql-connection-string    (Expires: 2026-03-15) 🔴         │      │
│  │  • openai-api-key           (Expires: 2027-01-01) ✅         │      │
│  └──────────────────────────────────────────────────────────────┘      │
└───────────┬───────────────────────────────────┬─────────────────────────┘
            │                                   │
            │ Diagnostic Logs                   │ Python SDK Access
            │ (AuditEvent, Metrics)             │ (List + Get Secrets)
            ▼                                   ▼
┌───────────────────────────────┐   ┌──────────────────────────────────┐
│   Azure Monitor               │   │  Python Script                    │
│   Log Analytics Workspace     │   │  check-keyvault-secrets.py       │
│                               │   │                                   │
│  Tables:                      │   │  ✓ Enumerate secrets             │
│  • AzureDiagnostics           │   │  ✓ Check expiration dates        │
│  • AzureMetrics               │◄──┤  ✓ Calculate days until expiry  │
│  • KeyVaultSecretExpiry_CL    │   │  ✓ Send to Log Analytics         │
│    (Custom logs from script)  │   │  ✓ Generate reports              │
└───────────┬───────────────────┘   └──────────────────────────────────┘
            │                                   ▲
            │                                   │
            │                          ┌────────┴─────────┐
            │                          │ Scheduled via:   │
            │                          │ • Cron Job       │
            │                          │ • GitHub Actions │
            │                          │ • Azure Runbook  │
            │                          └──────────────────┘
            │
            ├──────────────────────┬──────────────────────┬────────────────┐
            │                      │                      │                │
            ▼                      ▼                      ▼                ▼
┌─────────────────────┐ ┌──────────────────┐ ┌─────────────────┐ ┌──────────────┐
│  Azure Workbook     │ │  Alert Rules     │ │  Action Group   │ │  KQL Queries │
│  Dashboard          │ │                  │ │                 │ │              │
│                     │ │  • Expiring      │ │  📧 Email       │ │  Ad-hoc      │
│  📊 Visualizations: │ │    Secrets       │ │  📱 SMS         │ │  Analysis    │
│  • Pie Charts       │ │  • High API      │ │  🔔 Webhooks    │ │              │
│  • Timelines        │ │    Usage         │ │  ⚡ Functions   │ │  • Audit     │
│  • Tables           │ │  • Availability  │ │                 │ │  • Security  │
│  • Heat Maps        │ │    Issues        │ │                 │ │  • Access    │
└─────────────────────┘ └──────────────────┘ └─────────────────┘ └──────────────┘
```

## Data Flow

```
        ╔════════════════════════════════════════════════════════╗
        ║               DATA COLLECTION FLOW                      ║
        ╚════════════════════════════════════════════════════════╝

1️⃣  Key Vault Operations (User/App Access)
    │
    └──► Generates Audit Logs
         │
         └──► Sent to Log Analytics (via Diagnostic Settings)
              │
              └──► Stored in AzureDiagnostics table

2️⃣  Python Script (check-keyvault-secrets.py)
    │
    ├──► Connect to Key Vault (Azure SDK)
    │    │
    │    └──► List all secrets + properties
    │
    ├──► Calculate expiration status
    │    │
    │    └──► Status: Expired, Critical, Warning, Notice, OK
    │
    └──► Send to Log Analytics (via HTTP Data Collector API)
         │
         └──► Stored in KeyVaultSecretExpiry_CL table

3️⃣  Azure Monitor Metrics
    │
    └──► Built-in Key Vault metrics
         │
         └──► Availability, ServiceApiHit, ServiceApiLatency
              │
              └──► Stored in AzureMetrics table


        ╔════════════════════════════════════════════════════════╗
        ║               ALERTING & REPORTING FLOW                 ║
        ╚════════════════════════════════════════════════════════╝

┌──────────────────────────────────────────────────────────────────┐
│  Log Analytics Workspace (Central Data Store)                    │
│                                                                   │
│  Query Engine runs scheduled queries and evaluates conditions    │
└──────────────────┬──────────────────────────────────────────────┘
                   │
                   ├──► Scheduled Query Alert
                   │    └──► "Secrets expiring in 30 days"
                   │         │
                   │         └──► Triggers Action Group
                   │              │
                   │              └──► 📧 Email to admins
                   │
                   ├──► Metric Alert  
                   │    └──► "High API usage >1000 req/15min"
                   │         │
                   │         └──► Triggers Action Group
                   │
                   └──► Dashboard Queries (On-Demand)
                        └──► Azure Workbook renders visualizations
                             │
                             └──► User views in browser
```

## Component Interaction

```
┌─────────────────────────────────────────────────────────────────┐
│                         TERRAFORM                                │
│  Infrastructure as Code                                          │
│                                                                  │
│  Deploys:                                                        │
│  ✓ azurerm_key_vault                                            │
│  ✓ azurerm_log_analytics_workspace                              │
│  ✓ azurerm_monitor_diagnostic_setting (Key Vault)               │
│  ✓ azurerm_monitor_action_group (Email/SMS)                     │
│  ✓ azurerm_monitor_scheduled_query_rules_alert_v2 (Expiry)      │
│  ✓ azurerm_monitor_metric_alert (API Usage, Availability)       │
└───────────────────────────────┬─────────────────────────────────┘
                                │
                                │ terraform apply
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AZURE RESOURCES                             │
│                                                                  │
│  [Key Vault] ──logs──► [Log Analytics] ◄──custom logs── [Script]│
│       │                      │                             │     │
│       │                      ├──queries──► [Workbook]      │     │
│       │                      │                             │     │
│       │                      └──triggers─► [Alerts] ──► [Email] │
│       │                                                          │
│       └──SDK access──► [Python Script]                          │
└─────────────────────────────────────────────────────────────────┘
                                │
                                │ User Access/Automation
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                         USERS / AUTOMATION                       │
│                                                                  │
│  • Admin runs: ./scripts/setup-keyvault-monitoring.sh           │
│  • Cron runs: check-keyvault-secrets.py (daily)                 │
│  • Admin views: Azure Workbook dashboard                        │
│  • Admin receives: Email alerts for expiring secrets            │
│  • DevOps queries: Log Analytics with KQL                       │
└─────────────────────────────────────────────────────────────────┘
```

## Secret Lifecycle & Monitoring

```
╔══════════════════════════════════════════════════════════════════════╗
║                    SECRET LIFECYCLE STAGES                            ║
╚══════════════════════════════════════════════════════════════════════╝

                    SECRET CREATED
                         │
                         │ az keyvault secret set --expires 2026-12-31
                         ▼
                ┌─────────────────┐
                │   ACTIVE        │ Status: 🟢 OK
                │   (>90 days)    │ Action: None
                └────────┬────────┘
                         │
                         │ Time passes...
                         ▼
                ┌─────────────────┐
                │   NOTICE        │ Status: 🔵 Notice (90 days)
                │   (≤90 days)    │ Action: Review, plan rotation
                └────────┬────────┘
                         │
                         │
                         ▼
                ┌─────────────────┐
                │   WARNING       │ Status: 🟡 Warning (30 days)
                │   (≤30 days)    │ Action: Schedule rotation
                └────────┬────────┘
                         │
                         │ ⚠️ Dashboard shows warning
                         ▼
                ┌─────────────────┐
                │   CRITICAL      │ Status: 🟠 Critical (7 days)
                │   (≤7 days)     │ Action: URGENT - Rotate secret
                └────────┬────────┘
                         │
                         │ 🚨 Email alert sent
                         ▼
                ┌─────────────────┐
                │   EXPIRED       │ Status: 🔴 EXPIRED
                │   (<0 days)     │ Action: IMMEDIATE rotation required
                └────────┬────────┘
                         │
                         │
                         ▼
              ┌──────────────────────┐
              │  MANUAL INTERVENTION │
              │  Required            │
              └──────────┬───────────┘
                         │
                         ├──► OPTION 1: Rotate Secret
                         │    │
                         │    ├──► Create new version
                         │    ├──► Update applications
                         │    └──► Disable old version
                         │         │
                         │         └──► Back to ACTIVE
                         │
                         └──► OPTION 2: Extend Expiration
                              │
                              └──► Update expiration date
                                   │
                                   └──► Back to appropriate stage
```

## Security Monitoring Flow

```
╔══════════════════════════════════════════════════════════════════════╗
║                    SECURITY EVENT MONITORING                          ║
╚══════════════════════════════════════════════════════════════════════╝

User/App attempts to access Key Vault Secret
│
├──► SUCCESS (ResultSignature: OK)
│    │
│    ├──► Logged: AzureDiagnostics
│    │    • TimeGenerated
│    │    • OperationName: SecretGet
│    │    • CallerIPAddress
│    │    • identity_claim_upn_s
│    │    • SecretName (extracted from id_s)
│    │
│    └──► Visible in Dashboard:
│         • Recent Activity table
│         • Top Accessed Secrets
│         • Access Patterns timeline
│
└──► FAILURE (ResultSignature: Unauthorized/Forbidden/NotFound)
     │
     ├──► Logged: AzureDiagnostics
     │    • ResultDescription: Error details
     │    • CallerIPAddress
     │    • identity_claim_upn_s
     │
     ├──► Alert Triggered (if threshold exceeded)
     │    │
     │    └──► Email to security team
     │
     └──► Visible in Dashboard:
          • Failed Access Attempts table
          • Error Rate timeline
          • Security section (red alert)


┌────────────────────────────────────────────────────────────────┐
│  Access Pattern Analysis (Daily/Weekly)                        │
│                                                                 │
│  Query identifies:                                              │
│  • Unusual access times                                         │
│  • High frequency from single IP                                │
│  • Access from new geographic locations                         │
│  • Secrets not accessed in 90+ days (unused)                   │
│                                                                 │
│  Admin reviews → Investigates → Takes action                   │
└────────────────────────────────────────────────────────────────┘
```

## Multi-Vault Monitoring (Scaling)

```
╔══════════════════════════════════════════════════════════════════════╗
║            MONITORING MULTIPLE KEY VAULTS (ENTERPRISE)                ║
╚══════════════════════════════════════════════════════════════════════╝

┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  Key Vault   │   │  Key Vault   │   │  Key Vault   │   │  Key Vault   │
│  (Dev)       │   │  (Test)      │   │  (Staging)   │   │  (Prod)      │
└──────┬───────┘   └──────┬───────┘   └──────┬───────┘   └──────┬───────┘
       │                  │                  │                  │
       └──────────────────┴──────────────────┴──────────────────┘
                          │
                          │ All send diagnostic logs
                          ▼
             ┌────────────────────────────┐
             │  Centralized Log Analytics │
             │  Workspace                 │
             └────────────┬───────────────┘
                          │
          ┌───────────────┼───────────────┐
          │               │               │
          ▼               ▼               ▼
   [Dashboard]      [Alerts]         [Reports]
   Filter by        Per-vault        Export per
   environment      thresholds       environment


Python Script (Loop):
───────────────────
for vault in [dev, test, staging, prod]:
    secrets = check_vault(vault)
    send_to_loganalytics(secrets, vault_name=vault)

Dashboard (Filter):
──────────────────
| KeyVault Filter: [All ▼] [Dev] [Test] [Staging] [Prod] |
| Shows: Secrets expiring across selected environments    |
```

## File Structure & Purpose

```
azure-etl-project/
│
├── terraform/
│   ├── monitoring.tf              ← Alert rules, diagnostic settings
│   │   • azurerm_monitor_diagnostic_setting.keyvault_diagnostics
│   │   • azurerm_monitor_scheduled_query_rules_alert_v2
│   │   • azurerm_monitor_metric_alert.keyvault_*
│   │
│   └── keyvault.tf                ← Key Vault resource, secrets
│       • azurerm_key_vault
│       • azurerm_key_vault_secret (multiple)
│
├── monitoring/
│   ├── keyvault-dashboard.json    ← Azure Workbook JSON template
│   │   • Copy/paste into Azure Portal
│   │   • Visual dashboard with charts/tables
│   │
│   ├── kql-queries.md             ← KQL query library (Queries #15-27)
│   │   • Run in Log Analytics
│   │   • Ad-hoc analysis
│   │
│   ├── README_KEYVAULT.md         ← Complete documentation
│   │   • Architecture, setup, troubleshooting
│   │   • Best practices, maintenance
│   │
│   └── QUICKSTART_KEYVAULT.md     ← This quick reference
│       • Commands, common tasks
│
└── scripts/
    ├── check-keyvault-secrets.py  ← Main monitoring script
    │   • Lists all secrets
    │   • Calculates expiration
    │   • Sends to Log Analytics
    │   • Generates reports
    │
    └── setup-keyvault-monitoring.sh ← Automated setup
        • Configures diagnostic settings
        • Installs dependencies
        • Runs initial check
```

---

**Visual Legend:**
- 🟢 OK (>90 days until expiry)
- 🔵 Notice (≤90 days)
- 🟡 Warning (≤30 days)
- 🟠 Critical (≤7 days)
- 🔴 Expired (<0 days)
- ⚪ No expiry set
