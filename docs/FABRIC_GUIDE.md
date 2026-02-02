# Microsoft Fabric Integration Guide

## Overview

Microsoft Fabric is a unified analytics platform that brings together data engineering, data warehousing, data science, real-time analytics, and business intelligence into a single Software-as-a-Service (SaaS) platform.

This project deploys a Fabric capacity (F2 SKU) integrated with existing Azure resources:
- OneLake integration with Azure Data Lake Storage Gen2
- Direct connectivity to Azure SQL Database
- Seamless data flow from Databricks to Fabric
- Native Power BI integration for visualization

## Architecture

```
On-Premise Data → SHIR → Azure Data Factory
                            ↓
Azure Data Lake Gen2 (Bronze/Silver/Gold)
                            ↓
                    ┌───────┴───────┐
                    ↓               ↓
              Databricks        Fabric Lakehouse
                    ↓               ↓
                Azure SQL       Fabric Warehouse
                    ↓               ↓
              Monitoring    Power BI + Analytics
```

## Deployed Resources

### Fabric Capacity
- **Name**: `fc-etl-{suffix}`
- **SKU**: F2 (minimum production SKU)
- **Cost**: ~$262/month (hourly billing available)
- **Location**: East US 2
- **Managed Identity**: System-assigned for secure resource access

### Role Assignments
1. **Storage Blob Data Contributor**: Fabric can read/write to Data Lake Gen2
2. **SQL DB Contributor**: Fabric can access Azure SQL Database
3. **Storage Account Access**: Via SAS token (stored in Key Vault)

### Storage Container
- **Container**: `fabric-data` (dedicated Fabric staging area)
- **Purpose**: Landing zone for Fabric ingestion jobs
- **Access**: Fabric capacity has full read/write via managed identity

## Workspace Setup

### 1. Create Fabric Workspace

Navigate to [Microsoft Fabric Portal](https://app.fabric.microsoft.com):

1. Click **Workspaces** → **New workspace**
2. **Name**: `etl-workspace-{suffix}`
3. **License mode**: Select your deployed capacity `fc-etl-{suffix}`
4. **Advanced Settings**:
   - Enable workspace deployment
   - Enable Git integration (optional)
5. Click **Apply**

### 2. Create Lakehouse

Within your workspace:

1. Click **New** → **More options**
2. Select **Lakehouse** under Data Engineering
3. **Name**: `bronze_lakehouse`, `silver_lakehouse`, `gold_lakehouse`
4. Create three lakehouses for medallion architecture

### 3. Configure OneLake Shortcuts

Connect existing Data Lake Gen2 data:

#### Bronze Lakehouse Shortcuts

1. Open `bronze_lakehouse`
2. Right-click **Files** → **New shortcut**
3. Select **Azure Data Lake Storage Gen2**
4. **Connection settings**:
   - Account name: `stetl{suffix}`
   - Container: `bronze-data`
   - Authentication: **Organizational account** or **Account key**
   - If using account key, retrieve from Key Vault secret
5. Name shortcut: `bronze_data_lake`
6. Click **Create**

Repeat for Silver and Gold lakehouses with respective containers.

### 4. Create Fabric Warehouse

For analytics workloads:

1. In workspace, click **New** → **Warehouse**
2. **Name**: `etl_warehouse`
3. Connect to data sources:
   - Import from lakehouse tables
   - Create views over OneLake shortcuts
   - Direct query Azure SQL Database

### 5. Create Data Pipeline

Build Fabric pipelines for orchestration:

1. Click **New** → **Data pipeline**
2. **Name**: `fabric_etl_pipeline`
3. **Activities**:
   - **Copy Data**: From `fabric-data` container to lakehouse
   - **Notebook**: Run transformation logic
   - **Stored Procedure**: Load to warehouse
4. **Schedule**: Hourly/Daily based on requirements

## Integration Patterns

### Pattern 1: ADF → Fabric Lakehouse

```
1. ADF pipeline copies on-prem data to fabric-data container
2. Fabric pipeline detects new files (event-driven trigger)
3. Fabric copies data to Bronze lakehouse
4. Fabric notebooks transform data → Silver/Gold
5. Power BI reads from Gold lakehouse tables
```

### Pattern 2: Databricks → Fabric

```
1. Databricks writes Delta tables to ADLS Gen2
2. Fabric creates OneLake shortcuts to Delta folders
3. Fabric treats Delta tables as native lakehouse tables
4. Direct SQL queries over Delta via Fabric SQL Endpoint
```

### Pattern 3: Real-Time Analytics

```
1. ADF triggers on file arrival
2. Fabric Eventstream ingests data in real-time
3. Fabric KQL database stores time-series data
4. Real-Time Dashboard updates automatically
```

## Configuration

### Retrieve Fabric Capacity ID

```bash
cd terraform
terraform output fabric_capacity_id
```

### Get Storage SAS Token

```bash
# From Key Vault
az keyvault secret show \
  --vault-name kv-etl-{suffix} \
  --name fabric-storage-sas \
  --query value -o tsv
```

### Configure Managed Identity Access

Fabric capacity already has access via deployed role assignments:

- Storage Blob Data Contributor (Data Lake Gen2)
- SQL DB Contributor (Azure SQL Database)

To verify:

```bash
az role assignment list \
  --assignee $(az fabric capacity show \
    --name fc-etl-{suffix} \
    --resource-group rg-azure-etl-project \
    --query identity.principalId -o tsv) \
  --all
```

## Fabric Notebooks

Create Spark notebooks in Fabric for data transformation:

### Sample: Fabric Bronze to Silver

```python
# Load data from Bronze lakehouse
df = spark.read.format("delta").load("Tables/bronze_employees")

# Apply transformations
from pyspark.sql.functions import col, current_timestamp, hash

df_silver = df \
    .filter(col("employee_id").isNotNull()) \
    .withColumn("processed_timestamp", current_timestamp()) \
    .withColumn("row_hash", hash(col("employee_id"), col("name"), col("email")))

# Write to Silver lakehouse
df_silver.write \
    .format("delta") \
    .mode("overwrite") \
    .option("overwriteSchema", "true") \
    .saveAsTable("silver_employees")

print(f"Processed {df_silver.count()} records to Silver layer")
```

### Sample: Load to Warehouse

```python
# Read from Gold lakehouse
df_gold = spark.read.format("delta").load("Tables/gold_employee_summary")

# Write to Fabric Warehouse
df_gold.write \
    .format("synapse") \
    .option("url", "https://etl-warehouse-{suffix}.datawarehouse.fabric.microsoft.com") \
    .option("dbtable", "dbo.employee_summary") \
    .mode("overwrite") \
    .save()
```

## Power BI Integration

### Connect Power BI to Lakehouse

1. Open Power BI Desktop
2. **Get Data** → **OneLake data hub**
3. Select your workspace and lakehouse
4. Choose tables to import (Silver/Gold layers)
5. Build visualizations
6. Publish to Fabric workspace

### Direct Lake Mode

For real-time reporting without import:

1. In Power BI Desktop, create semantic model
2. Select **Direct Lake** connection mode
3. Point to Fabric lakehouse SQL endpoint
4. Queries run directly over Delta tables
5. Near real-time refresh without data movement

## Cost Optimization

### Pause Capacity

When not in use:

```bash
az fabric capacity update \
  --name fc-etl-{suffix} \
  --resource-group rg-azure-etl-project \
  --suspend
```

Resume capacity:

```bash
az fabric capacity update \
  --name fc-etl-{suffix} \
  --resource-group rg-azure-etl-project \
  --resume
```

### Scaling

Adjust capacity SKU based on workload:

```bash
# Upgrade to F4
terraform apply -var="fabric_sku=F4"

# Downgrade to F2
terraform apply -var="fabric_sku=F2"
```

### Cost Breakdown

- **F2 Capacity**: ~$262/month
- **Storage**: Included in Data Lake Gen2 costs
- **Compute**: Included in capacity reservation
- **Power BI**: Included (1 workspace per capacity)

## Monitoring

### Fabric Metrics

Monitor capacity utilization in Azure Portal:

1. Navigate to **fc-etl-{suffix}** resource
2. **Metrics** → Select:
   - CPU percentage
   - Memory percentage
   - Throttling events
   - Active queries

### Fabric Admin Portal

Access via [Fabric Admin Portal](https://app.fabric.microsoft.com/admin):

- Capacity utilization by workspace
- Audit logs for compliance
- Usage metrics per artifact
- Performance recommendations

### Log Analytics Integration

Fabric diagnostic logs are sent to Log Analytics workspace:

```kusto
FabricCapacityLogs
| where TimeGenerated > ago(24h)
| where CapacityName == "fc-etl-{suffix}"
| summarize 
    TotalOperations = count(),
    AvgDuration = avg(DurationMs),
    ErrorCount = countif(Status == "Failed")
  by OperationType
| order by TotalOperations desc
```

## Best Practices

### 1. Data Organization

- Use medallion architecture (Bronze/Silver/Gold)
- Store raw data in Bronze lakehouse
- Apply transformations in Silver
- Create business-ready tables in Gold
- Use OneLake shortcuts for external data

### 2. Security

- Use managed identities for authentication
- Apply workspace access controls
- Enable row-level security in semantic models
- Audit data access via Log Analytics
- Rotate SAS tokens regularly

### 3. Performance

- Partition large tables by date
- Use Direct Lake mode for Power BI
- Optimize Delta tables with OPTIMIZE and VACUUM
- Cache frequently accessed data
- Monitor capacity utilization

### 4. Governance

- Tag all artifacts with project metadata
- Document data lineage
- Implement data quality checks
- Create data dictionaries
- Version control notebooks via Git

## Troubleshooting

### Issue: Capacity Not Available in Workspace

Solution: Wait 5-10 minutes after Terraform deployment for capacity provisioning to complete.

### Issue: OneLake Shortcut Connection Failed

Solution: Verify Fabric managed identity has Storage Blob Data Contributor role:

```bash
az role assignment list \
  --scope /subscriptions/{subscription}/resourceGroups/rg-azure-etl-project/providers/Microsoft.Storage/storageAccounts/stetl{suffix} \
  --query "[?roleDefinitionName=='Storage Blob Data Contributor']"
```

### Issue: SQL Database Connection Failed

Solution: Add Fabric capacity IP to SQL firewall rules or enable Azure service access.

### Issue: High Capacity Utilization

Solution: Analyze workload distribution and consider upgrading SKU or moving long-running jobs to Databricks.

## Additional Resources

- [Microsoft Fabric Documentation](https://learn.microsoft.com/fabric/)
- [OneLake Overview](https://learn.microsoft.com/fabric/onelake/)
- [Fabric Lakehouse Tutorial](https://learn.microsoft.com/fabric/data-engineering/tutorial-lakehouse-introduction)
- [Direct Lake Mode](https://learn.microsoft.com/power-bi/enterprise/directlake-overview)
- [Fabric Pricing](https://azure.microsoft.com/pricing/details/microsoft-fabric/)
