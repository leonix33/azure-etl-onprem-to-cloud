#!/bin/bash

# Monitoring Dashboard Setup Script
# Creates Azure Monitor workbook with KQL queries

set -e

echo "========================================="
echo "Setting up Monitoring Dashboard"
echo "========================================="

# Get workspace ID
WORKSPACE_ID=$(terraform output -raw log_analytics_workspace_id 2>/dev/null)
WORKSPACE_NAME=$(terraform output -raw log_analytics_workspace_name 2>/dev/null)
RG_NAME=$(terraform output -raw resource_group_name 2>/dev/null)

if [ -z "$WORKSPACE_ID" ]; then
    echo "Error: Log Analytics workspace not found. Deploy monitoring infrastructure first."
    exit 1
fi

echo "Log Analytics Workspace: $WORKSPACE_NAME"
echo "Resource Group: $RG_NAME"
echo ""

# Create monitoring dashboard
echo "Creating Azure Monitor Workbook..."

WORKBOOK_JSON=$(cat <<'EOF'
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "## Azure ETL Pipeline Monitoring Dashboard\n\nReal-time monitoring and performance metrics for the ETL pipeline"
      },
      "name": "text - 0"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "ADFPipelineRun\n| where TimeGenerated > ago(24h)\n| summarize Total = count(), Succeeded = countif(Status == \"Succeeded\"), Failed = countif(Status == \"Failed\")\n| extend SuccessRate = round(100.0 * Succeeded / Total, 2)\n| project SuccessRate, Total, Succeeded, Failed",
        "size": 3,
        "title": "Pipeline Success Rate (24h)",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces",
        "visualization": "tiles"
      },
      "name": "query - 1"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "ADFPipelineRun\n| where TimeGenerated > ago(7d)\n| summarize Total = count(), Succeeded = countif(Status == \"Succeeded\"), Failed = countif(Status == \"Failed\") by bin(TimeGenerated, 1h)\n| render timechart",
        "size": 0,
        "title": "Pipeline Runs Trend (7 days)",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      },
      "name": "query - 2"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "AzureMetrics\n| where ResourceProvider == \"MICROSOFT.SQL\"\n| where MetricName == \"dtu_consumption_percent\"\n| summarize AvgDTU = avg(Average), MaxDTU = max(Maximum) by bin(TimeGenerated, 5m)\n| render timechart",
        "size": 0,
        "title": "SQL Database DTU Usage",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      },
      "name": "query - 3"
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "ADFActivityRun\n| where TimeGenerated > ago(24h)\n| where Status == \"Failed\"\n| summarize FailureCount = count() by ActivityName, ErrorCode\n| order by FailureCount desc\n| take 10",
        "size": 0,
        "title": "Top Failure Reasons",
        "queryType": 0,
        "resourceType": "microsoft.operationalinsights/workspaces"
      },
      "name": "query - 4"
    }
  ],
  "fallbackResourceIds": [
    "$WORKSPACE_ID"
  ]
}
EOF
)

# Save workbook JSON
WORKBOOK_FILE="/tmp/etl-workbook-${RANDOM}.json"
echo "$WORKBOOK_JSON" > "$WORKBOOK_FILE"

echo "Workbook template created: $WORKBOOK_FILE"
echo ""

# Create workbook using Azure CLI
WORKBOOK_NAME="ETL-Monitoring-Dashboard"
WORKBOOK_DISPLAY_NAME="Azure ETL Pipeline Monitoring"

echo "Deploying workbook to Azure..."

az monitor app-insights workbook create \
  --resource-group "$RG_NAME" \
  --name "$WORKBOOK_NAME" \
  --location "$(terraform output -raw location 2>/dev/null || echo 'eastus2')" \
  --display-name "$WORKBOOK_DISPLAY_NAME" \
  --category "workbook" \
  --serialized-data "@$WORKBOOK_FILE" \
  --tags Project=Azure-ETL ManagedBy=Terraform \
  2>/dev/null || echo "Note: Workbook creation via CLI may require additional setup"

echo ""
echo "========================================="
echo "Monitoring Dashboard Setup Complete!"
echo "========================================="
echo ""
echo "Access your monitoring resources:"
echo ""
echo "1. Log Analytics Workspace:"
echo "   https://portal.azure.com/#@/resource${WORKSPACE_ID}/logs"
echo ""
echo "2. Azure Monitor Workbooks:"
echo "   https://portal.azure.com/#blade/AppInsightsExtension/WorkbooksGalleryBlade"
echo ""
echo "3. Alerts & Action Groups:"
echo "   https://portal.azure.com/#blade/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade/alertsV2"
echo ""
echo "Sample KQL queries available in: monitoring/kql-queries.md"
echo "========================================="
