# Azure ETL Project - Monitoring & Observability Guide

## Overview

This project includes comprehensive monitoring and observability features to showcase production-ready operational excellence. The monitoring stack includes:

- **Log Analytics Workspace**: Centralized logging for all Azure resources
- **Application Insights**: Advanced telemetry and performance tracking
- **Azure Monitor Alerts**: Proactive notifications for failures and performance issues
- **Cost Management**: Budget alerts to prevent cost overruns
- **Custom KQL Queries**: Pre-built queries for common monitoring scenarios

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Log Analytics Workspace                 │
│                  (Centralized Logging)                   │
└───────────┬─────────────────────────────────┬───────────┘
            │                                 │
    ┌───────▼────────┐                ┌──────▼─────────┐
    │  Data Factory  │                │  SQL Database  │
    │  Diagnostics   │                │   Diagnostics  │
    └───────┬────────┘                └──────┬─────────┘
            │                                │
    ┌───────▼────────────────────────────────▼─────────┐
    │          Azure Monitor Alerts                     │
    │  • Pipeline Failures                              │
    │  • High DTU Usage                                 │
    │  • Storage Availability                           │
    └───────────────────────┬───────────────────────────┘
                            │
                    ┌───────▼────────┐
                    │  Action Group  │
                    │  (Email Alerts)│
                    └────────────────┘
```

## Deployed Monitoring Resources

### 1. Log Analytics Workspace
- **Name**: `log-etl-{suffix}`
- **Retention**: 30 days
- **SKU**: Pay-as-you-go (PerGB2018)
- **Purpose**: Centralized log aggregation for all resources

### 2. Diagnostic Settings

**Data Factory**:
- Pipeline Runs
- Trigger Runs
- Activity Runs
- All Metrics

**SQL Database**:
- SQL Insights
- Errors
- Query Store Runtime Statistics
- Basic Metrics

**Storage Account**:
- Transaction Metrics
- Capacity Metrics

### 3. Azure Monitor Alerts

| Alert Name | Resource | Metric | Threshold | Severity |
|-----------|----------|---------|-----------|----------|
| Pipeline Failures | Data Factory | PipelineFailedRuns | > 0 | 2 (Warning) |
| High DTU Usage | SQL Database | dtu_consumption_percent | > 80% | 3 (Informational) |
| Storage Availability | Storage Account | Availability | < 99% | 2 (Warning) |

### 4. Cost Management
- **Monthly Budget**: $100
- **Alert at 80%**: $80 spent
- **Alert at 100%**: $100 spent (budget exceeded)

### 5. Application Insights
- **Name**: `appi-etl-{suffix}`
- **Type**: Other (generic telemetry)
- **Purpose**: Advanced performance monitoring

## Quick Start

### 1. Deploy Monitoring Infrastructure

```bash
cd terraform
terraform apply -var="allowed_ip_addresses=[\"YOUR_IP/32\"]" \
                -var="alert_email_address=YOUR_EMAIL@example.com"
```

### 2. Setup Monitoring Dashboard

```bash
./scripts/setup-monitoring.sh
```

### 3. Access Monitoring Resources

**Log Analytics Workspace**:
```bash
WORKSPACE_ID=$(terraform output -raw log_analytics_workspace_id)
echo "https://portal.azure.com/#@/resource${WORKSPACE_ID}/logs"
```

**Azure Monitor Workbooks**:
- Go to Azure Portal → Monitor → Workbooks
- Find "Azure ETL Pipeline Monitoring" dashboard

## Using KQL Queries

### Access Log Analytics

1. Go to Azure Portal → Log Analytics workspaces
2. Select `log-etl-{suffix}`
3. Click "Logs" in the left menu
4. Use queries from `monitoring/kql-queries.md`

### Sample Queries

**Pipeline Success Rate (Last 24 Hours)**:
```kql
ADFPipelineRun
| where TimeGenerated > ago(24h)
| summarize 
    Total = count(),
    Succeeded = countif(Status == "Succeeded"),
    Failed = countif(Status == "Failed")
| extend SuccessRate = round(100.0 * Succeeded / Total, 2)
```

**Top 10 Slowest Queries**:
```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.SQL"
| where Category == "QueryStoreRuntimeStatistics"
| extend Duration = todouble(duration_d)
| top 10 by Duration desc
```

**Storage Transaction Trend**:
```kql
AzureMetrics
| where ResourceProvider == "MICROSOFT.STORAGE"
| where MetricName == "Transactions"
| summarize TotalTransactions = sum(Total) by bin(TimeGenerated, 1h)
| render timechart
```

## Alert Configuration

### Email Notifications

Update the email address in `terraform/variables.tf`:

```terraform
variable "alert_email_address" {
  default = "your-email@example.com"
}
```

Then reapply:
```bash
terraform apply -var="alert_email_address=your-email@example.com"
```

### Adding More Alert Rules

Edit `terraform/monitoring.tf` and add new alert resources:

```terraform
resource "azurerm_monitor_metric_alert" "custom_alert" {
  name                = "custom-alert-name"
  resource_group_name = azurerm_resource_group.etl_rg.name
  scopes              = [azurerm_resource_id.id]
  description         = "Alert description"
  
  criteria {
    metric_namespace = "Microsoft.DataFactory/factories"
    metric_name      = "PipelineSucceededRuns"
    aggregation      = "Total"
    operator         = "LessThan"
    threshold        = 1
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.etl_alerts.id
  }
}
```

## Creating Custom Dashboards

### Option 1: Azure Portal Dashboard

1. Go to Azure Portal → Dashboard
2. Click "Create" → "Custom"
3. Add tiles for:
   - Pipeline success rate
   - SQL DTU usage
   - Storage metrics
   - Cost analysis

### Option 2: Power BI Dashboard

1. Connect Power BI to Log Analytics workspace
2. Use KQL queries as data sources
3. Create visualizations:
   - Pipeline success trends
   - Data volume processed
   - Error analysis
   - Cost breakdown

### Option 3: Azure Monitor Workbook

1. Go to Azure Monitor → Workbooks
2. Click "New"
3. Add query-based visualizations
4. Save as "ETL Monitoring Dashboard"

## Monitoring Best Practices

### 1. Regular Review
- Check dashboard daily during development
- Review alerts weekly
- Analyze trends monthly

### 2. Alert Fatigue Prevention
- Set appropriate thresholds
- Use severity levels correctly
- Group related alerts
- Add suppression rules for maintenance

### 3. Cost Optimization
- Monitor Log Analytics ingestion volume
- Set appropriate retention periods
- Archive old logs to storage
- Use sampling for high-volume metrics

### 4. Performance Tuning
- Identify slow queries from logs
- Optimize pipeline activities
- Right-size resources based on metrics
- Use insights to reduce costs

## Troubleshooting

### No Data in Log Analytics

**Issue**: No logs appearing in workspace

**Solution**:
1. Verify diagnostic settings are enabled
2. Check resource has activity (run a pipeline)
3. Wait 5-15 minutes for initial ingestion
4. Verify time range in queries

### Alerts Not Firing

**Issue**: Configured alerts don't send notifications

**Solution**:
1. Verify Action Group email is confirmed
2. Check alert conditions are being met
3. Review alert evaluation frequency
4. Check spam folder for notifications

### High Costs

**Issue**: Monitoring costs higher than expected

**Solution**:
1. Review Log Analytics ingestion volume
2. Reduce retention period if possible
3. Disable verbose logging
4. Use sampling for metrics

## Monitoring Metrics Reference

### Data Factory Metrics
- `PipelineSucceededRuns`: Successful pipeline executions
- `PipelineFailedRuns`: Failed pipeline executions
- `ActivitySucceededRuns`: Successful activity executions
- `TriggerSucceededRuns`: Successful trigger executions

### SQL Database Metrics
- `dtu_consumption_percent`: DTU usage percentage
- `storage_percent`: Storage usage percentage
- `connection_successful`: Successful connections
- `deadlock`: Number of deadlocks

### Storage Metrics
- `Transactions`: Total API transactions
- `Availability`: Availability percentage
- `SuccessE2ELatency`: End-to-end latency
- `Egress`: Data transferred out

## Cost Analysis

### Estimated Monitoring Costs

| Service | Monthly Cost |
|---------|-------------|
| Log Analytics (5GB/month) | ~$2.50 |
| Application Insights (1GB/month) | ~$2.30 |
| Alert Rules (5 rules) | ~$0.10 |
| **Total** | **~$5/month** |

*Note: Actual costs depend on data volume and retention*

## Next Steps

1. **Customize Alerts**: Adjust thresholds based on your workload
2. **Create Dashboards**: Build visual dashboards in Power BI or Azure
3. **Set Up Automation**: Use Logic Apps for advanced alert responses
4. **Integrate with Tools**: Connect to Slack, Teams, or PagerDuty
5. **Enable Advanced Features**: Application Map, Live Metrics, Smart Detection

## Resources

- [Azure Monitor Documentation](https://docs.microsoft.com/azure/azure-monitor/)
- [KQL Reference](https://docs.microsoft.com/azure/data-explorer/kusto/query/)
- [Alert Best Practices](https://docs.microsoft.com/azure/azure-monitor/alerts/alerts-best-practices)
- [Log Analytics Pricing](https://azure.microsoft.com/pricing/details/monitor/)

---

**Project**: Azure ETL On-Premise to Cloud  
**Monitoring Version**: 1.0  
**Last Updated**: February 2026
