# Deployment Guide

## Step-by-Step Deployment

### Phase 1: Pre-Deployment Checklist

- [ ] Azure CLI installed and configured
- [ ] Terraform 1.0+ installed
- [ ] Azure subscription active
- [ ] Sufficient permissions (Contributor role minimum)
- [ ] RDP client available

### Phase 2: Infrastructure Deployment

```bash
cd /Users/user/Desktop/Development/azure-etl-project
./scripts/deploy.sh
```

**Expected Duration**: 10-15 minutes

**What gets created**:
- Resource Group
- Virtual Network & Subnets
- Network Security Group
- Public IP Address
- Windows VM (SHIR host)
- Storage Account with 3 containers
- Azure SQL Server & Database
- Azure Key Vault with secrets
- Azure Data Factory with SHIR

### Phase 3: SHIR Configuration

1. **Get SHIR Key**:
   ```bash
   ./scripts/get-shir-key.sh
   ```
   Copy the displayed key.

2. **Connect to VM**:
   - Get VM IP: Check deployment output
   - Username: `azureadmin`
   - Password: Get from Key Vault
     ```bash
     az keyvault secret show --vault-name <kv-name> --name vm-admin-password --query value -o tsv
     ```

3. **Install SHIR on VM**:
   - Download: https://aka.ms/dmg
   - Install the MSI
   - Open Integration Runtime Configuration Manager
   - Paste the authentication key
   - Click "Register"

   **OR use automated script**:
   ```powershell
   # On the VM, run:
   .\install-shir.ps1 -AuthKey "YOUR_KEY_HERE"
   ```

### Phase 4: SQL Database Setup

1. **Get SQL Connection Info**:
   ```bash
   cd terraform
   terraform output sql_server_fqdn
   terraform output sql_database_name
   ```

2. **Connect using Azure Data Studio or SSMS**:
   - Server: `<output-from-above>`
   - Database: `<output-from-above>`
   - Authentication: SQL Authentication
   - Username: `sqladmin`
   - Password: Get from Key Vault (`sql-connection-string`)

3. **Run Setup Script**:
   Execute `adf-pipelines/sql_setup.sql` to create:
   - `dbo.Employees` table
   - Indexes
   - Views

### Phase 5: Upload Sample Data

**Option A: Copy to VM via RDP**
1. RDP to VM
2. Copy `sample-data/employees.csv` to `C:\OnPremiseData\`

**Option B: Use Azure Storage**
1. Upload to storage account file share
2. Mount share on VM
3. Copy to `C:\OnPremiseData\`

### Phase 6: Configure Data Factory

1. **Navigate to Azure Portal**:
   ```bash
   open https://portal.azure.com
   ```

2. **Open Data Factory**:
   - Search for your Data Factory
   - Click "Author & Monitor"

3. **Verify Linked Services**:
   - Check `ls_onprem_filesystem`
   - Check `ls_azure_blob_storage`
   - Check `ls_azure_sql_database`
   - Test connections

4. **Import or Create Datasets**:
   - `ds_onprem_csv`
   - `ds_blob_raw_csv`
   - `ds_blob_archive_csv`
   - `ds_sql_employees`

5. **Import or Create Pipeline**:
   - `OnPrem_to_Azure_ETL_Pipeline`

### Phase 7: Test the Pipeline

1. **Debug Run**:
   - Open pipeline in ADF
   - Click "Debug"
   - Monitor progress

2. **Verify Results**:
   
   **Check Blob Storage**:
   ```bash
   az storage blob list \
     --account-name <storage-account> \
     --container-name raw-data \
     --output table
   ```

   **Check SQL Database**:
   ```sql
   SELECT COUNT(*) FROM dbo.Employees;
   SELECT * FROM dbo.Employees ORDER BY LoadedDate DESC;
   ```

   **Check Archive**:
   ```bash
   az storage blob list \
     --account-name <storage-account> \
     --container-name archive-data \
     --output table
   ```

### Phase 8: Schedule Pipeline (Optional)

1. In Data Factory, click "Add Trigger" → "New/Edit"
2. Choose schedule:
   - **Daily**: Run at specific time
   - **Hourly**: Run every hour
   - **Event-based**: On file arrival
3. Save and publish

### Phase 9: Enable AI Search + OpenAI RAG (Optional)

1. Create AI Search index and indexer:
   ```bash
   ./scripts/setup-ai-search-rag.sh
   ```

2. Deploy an OpenAI model in Azure OpenAI Studio (e.g., `gpt-4o-mini`).

3. Run a RAG query:
   ```bash
   python3 scripts/rag-query.py
   ```

## Post-Deployment Verification

### Checklist

- [ ] VM is running and accessible
- [ ] SHIR shows "Running" status in ADF
- [ ] All Linked Services test successfully
- [ ] Sample data exists in `C:\OnPremiseData`
- [ ] Pipeline debug run succeeds
- [ ] Data appears in Blob Storage
- [ ] Data loads into SQL Database
- [ ] Archive container has files

### Monitor Resources

```bash
./scripts/monitor.sh
```

## Troubleshooting

### SHIR Connection Issues

**Problem**: SHIR shows offline in Data Factory

**Solutions**:
1. Check VM is running
2. Verify SHIR service is running on VM
3. Check firewall allows outbound HTTPS (443)
4. Regenerate and re-register SHIR key

### Pipeline Copy Errors

**Problem**: Copy activity fails

**Solutions**:
1. Verify source files exist
2. Check file format (CSV with headers)
3. Test linked service connections
4. Review activity error details in Monitor

### SQL Connection Errors

**Problem**: Cannot connect to SQL Database

**Solutions**:
1. Add your IP to SQL firewall rules
2. Verify connection string in Key Vault
3. Check SQL Database is not paused
4. Test with Azure Data Studio

### Permission Errors

**Problem**: Data Factory cannot access Storage/SQL

**Solutions**:
1. Verify Managed Identity has correct roles
2. Check Key Vault access policies
3. Ensure secrets are not expired
4. Grant "Storage Blob Data Contributor" role to ADF

## Next Steps

After successful deployment:

1. **Customize Pipeline**:
   - Add transformations
   - Add validation steps
   - Implement error handling

2. **Add Monitoring**:
   - Set up alerts
   - Configure diagnostic logs
   - Create dashboards

3. **Implement DevOps**:
   - Set up CI/CD
   - Git integration
   - Environment promotion

4. **Optimize Costs**:
   - Review resource usage
   - Implement auto-shutdown
   - Use reserved instances

## Cleanup

When finished testing:

```bash
./scripts/cleanup.sh
```

**⚠️ Warning**: This destroys ALL resources. Ensure you've backed up any important data.

---

*For issues or questions, refer to ARCHITECTURE.md or Azure documentation.*
