# Azure Monitor KQL Queries for ETL Monitoring

## Pipeline Performance Queries

### 1. Pipeline Run Success Rate (Last 24 Hours)
```kql
ADFPipelineRun
| where TimeGenerated > ago(24h)
| summarize 
    Total = count(),
    Succeeded = countif(Status == "Succeeded"),
    Failed = countif(Status == "Failed"),
    Cancelled = countif(Status == "Cancelled")
| extend SuccessRate = round(100.0 * Succeeded / Total, 2)
| project SuccessRate, Total, Succeeded, Failed, Cancelled
```

### 2. Top 10 Slowest Pipeline Runs
```kql
ADFPipelineRun
| where TimeGenerated > ago(7d)
| where Status == "Succeeded"
| extend Duration = End - Start
| top 10 by Duration desc
| project PipelineName, Start, Duration, ResourceId
```

### 3. Pipeline Failure Analysis
```kql
ADFActivityRun
| where TimeGenerated > ago(24h)
| where Status == "Failed"
| summarize FailureCount = count() by ActivityName, ErrorCode, ErrorMessage
| order by FailureCount desc
```

### 4. Pipeline Runs by Hour (Trend)
```kql
ADFPipelineRun
| where TimeGenerated > ago(7d)
| summarize 
    Total = count(),
    Succeeded = countif(Status == "Succeeded"),
    Failed = countif(Status == "Failed")
    by bin(TimeGenerated, 1h)
| render timechart
```

### 5. Data Volume Processed
```kql
ADFActivityRun
| where TimeGenerated > ago(24h)
| where ActivityType == "Copy"
| extend BytesRead = todouble(Output.dataRead)
| extend BytesWritten = todouble(Output.dataWritten)
| summarize 
    TotalReadGB = sum(BytesRead) / 1GB,
    TotalWrittenGB = sum(BytesWritten) / 1GB
    by bin(TimeGenerated, 1h)
| render timechart
```

## SQL Database Performance Queries

### 6. Top 10 Slowest Queries
```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.SQL"
| where Category == "QueryStoreRuntimeStatistics"
| extend Duration = todouble(duration_d)
| top 10 by Duration desc
| project TimeGenerated, query_id_d, Duration, execution_type_s
```

### 7. Database DTU Usage Over Time
```kql
AzureMetrics
| where ResourceProvider == "MICROSOFT.SQL"
| where MetricName == "dtu_consumption_percent"
| summarize AvgDTU = avg(Average), MaxDTU = max(Maximum) by bin(TimeGenerated, 5m)
| render timechart
```

### 8. SQL Errors and Warnings
```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.SQL"
| where Category == "Errors"
| summarize ErrorCount = count() by error_message_s
| order by ErrorCount desc
```

## Storage Account Monitoring

### 9. Storage Transactions by API
```kql
AzureMetrics
| where ResourceProvider == "MICROSOFT.STORAGE"
| where MetricName == "Transactions"
| extend ApiName = tostring(split(Dimensions, "\"ApiName\":\"")[1])
| extend ApiName = tostring(split(ApiName, "\"")[0])
| summarize TotalTransactions = sum(Total) by ApiName, bin(TimeGenerated, 1h)
| render timechart
```

### 10. Storage Latency Analysis
```kql
AzureMetrics
| where ResourceProvider == "MICROSOFT.STORAGE"
| where MetricName in ("SuccessE2ELatency", "SuccessServerLatency")
| summarize AvgLatency = avg(Average) by MetricName, bin(TimeGenerated, 5m)
| render timechart
```

## Cost Analysis Queries

### 11. Estimated Daily Cost by Resource
```kql
AzureMetrics
| where TimeGenerated > ago(24h)
| summarize MetricCount = count() by Resource
| project Resource, MetricCount
// Note: Combine with Azure Cost Management for actual costs
```

## Alert Correlation

### 12. Alerts Triggered in Last 7 Days
```kql
AzureActivity
| where TimeGenerated > ago(7d)
| where CategoryValue == "Alert"
| summarize AlertCount = count() by AlertName = Properties.AlertName, Severity = Properties.Severity
| order by AlertCount desc
```

## Integration Runtime Performance

### 13. SHIR Availability and Performance
```kql
ADFPipelineRun
| where TimeGenerated > ago(7d)
| where Properties contains "SHIR-OnPremise"
| summarize 
    TotalRuns = count(),
    AvgDuration = avg(End - Start)
    by bin(TimeGenerated, 1h)
| render timechart
```

## Data Quality Checks

### 14. Data Copy Success Rate by Source
```kql
ADFActivityRun
| where TimeGenerated > ago(7d)
| where ActivityType == "Copy"
| extend SourceSystem = tostring(Input.source.type)
| summarize 
    Total = count(),
    Succeeded = countif(Status == "Succeeded"),
    Failed = countif(Status == "Failed")
    by SourceSystem
| extend SuccessRate = round(100.0 * Succeeded / Total, 2)
| project SourceSystem, SuccessRate, Total, Succeeded, Failed
```

## Usage Instructions

1. Go to Azure Portal → Log Analytics workspace
2. Click "Logs" in the left menu
3. Copy and paste any query above
4. Click "Run" to execute
5. Pin useful queries to a dashboard

## Creating Custom Workbooks

Navigate to Azure Monitor → Workbooks → Create a new workbook and add these queries as visualizations for a comprehensive monitoring dashboard.
