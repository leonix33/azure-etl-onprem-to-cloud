# Azure ETL Project: On-Premise to Cloud

[![Terraform](https://img.shields.io/badge/Terraform-1.0+-purple.svg)](https://www.terraform.io/)
[![Azure](https://img.shields.io/badge/Azure-Cloud-blue.svg)](https://azure.microsoft.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A complete end-to-end ETL (Extract, Transform, Load) solution for migrating data from on-premise systems to Azure Cloud using Azure Data Factory, Self-Hosted Integration Runtime, Key Vault, and Azure SQL Database.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     ON-PREMISE ENVIRONMENT                       │
│  ┌───────────────┐         ┌──────────────────────┐            │
│  │  File System  │────────>│  Windows VM (SHIR)   │            │
│  │  (CSV Files)  │         │  Self-Hosted IR      │            │
│  └───────────────┘         └──────────────────────┘            │
└────────────────────────────────────┬────────────────────────────┘
                                     │ Secure Connection
                                     │ (HTTPS)
                                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                       AZURE CLOUD                                │
│                                                                  │
│  ┌────────────────┐      ┌─────────────────────┐               │
│  │  Key Vault     │◀────│  Data Factory       │               │
│  │  (Secrets)     │      │  - Pipelines        │               │
│  └────────────────┘      │  - Datasets         │               │
│                          │  - Linked Services  │               │
│                          └─────────┬───────────┘               │
│                                    │                            │
│                   ┌────────────────┴────────────────┐          │
│                   ▼                                  ▼          │
│  ┌────────────────────────────┐    ┌───────────────────────┐  │
│  │  Blob Storage (Data Lake)  │    │  Azure SQL Database   │  │
│  │  - raw-data                │    │  - Employees Table    │  │
│  │  - processed-data          │    │  - Analytics Views    │  │
│  │  - archive-data            │    └───────────────────────┘  │
│  └────────────────────────────┘                                │
└─────────────────────────────────────────────────────────────────┘
```

## 🎯 Features

- **Self-Hosted Integration Runtime (SHIR)**: Secure connection between on-premise and cloud
- **Azure Key Vault**: Centralized secrets management for credentials
- **Azure Data Factory**: Orchestration of ETL pipelines
- **Azure Blob Storage**: Data Lake for raw, processed, and archived data
- **Azure SQL Database**: Target database for transformed data
- **Infrastructure as Code**: Complete Terraform automation
- **Auto-Shutdown**: Cost optimization with VM auto-shutdown
- **Secure by Default**: Network security groups, private endpoints, managed identities

## 📋 Prerequisites

- Azure CLI (`az`) installed and configured
- Terraform 1.0 or higher
- Active Azure subscription
- macOS/Linux terminal or Windows PowerShell
- RDP client for Windows VM access

## 🚀 Quick Start

### 1. Clone and Navigate

```bash
cd /Users/user/Desktop/Development/azure-etl-project
```

### 2. Review Configuration

Edit [terraform/variables.tf](terraform/variables.tf) to customize:
- Resource names
- Azure region
- VM size
- Tags

### 3. Deploy Infrastructure

```bash
./scripts/deploy.sh
```

This will:
- ✅ Initialize Terraform
- ✅ Create all Azure resources
- ✅ Configure networking and security
- ✅ Set up Key Vault with secrets
- ✅ Deploy Data Factory with SHIR
- ✅ Output connection details

### 4. Configure SHIR on VM

After deployment:

```bash
# Get the SHIR authentication key
./scripts/get-shir-key.sh
```

Then:
1. RDP to the VM (IP shown in deployment output)
2. Download SHIR installer: https://aka.ms/dmg
3. Run PowerShell as Administrator:
   ```powershell
   # Copy the key from get-shir-key.sh output
   .\install-shir.ps1 -AuthKey "YOUR_SHIR_KEY_HERE"
   ```

### 5. Set Up SQL Database

Connect to Azure SQL Database and run:

```bash
# Get SQL connection details
cd terraform
terraform output sql_server_fqdn
terraform output sql_database_name
```

Execute [adf-pipelines/sql_setup.sql](adf-pipelines/sql_setup.sql) to create tables and views.

### 6. Deploy ADF Pipelines

1. Navigate to [Azure Portal](https://portal.azure.com)
2. Open your Data Factory
3. Click "Author & Monitor"
4. Import pipeline definitions from `adf-pipelines/`

### 7. Test the Pipeline

The pipeline will:
1. **Extract**: Read CSV files from on-premise VM
2. **Load**: Copy to Azure Blob Storage (raw-data container)
3. **Transform**: Load into Azure SQL Database
4. **Archive**: Move processed files to archive container

## 📁 Project Structure

```
azure-etl-project/
├── terraform/              # Infrastructure as Code
│   ├── main.tf            # Main configuration
│   ├── variables.tf       # Input variables
│   ├── network.tf         # VNet, NSG, Subnets
│   ├── vm.tf              # SHIR VM
│   ├── keyvault.tf        # Key Vault and secrets
│   ├── storage.tf         # Blob Storage
│   ├── datafactory.tf     # ADF resources
│   ├── sql.tf             # SQL Database
│   └── outputs.tf         # Output values
├── scripts/               # Automation scripts
│   ├── deploy.sh          # Deploy infrastructure
│   ├── cleanup.sh         # Destroy resources
│   ├── get-shir-key.sh    # Get SHIR key
│   ├── install-shir.ps1   # Install SHIR on VM
│   └── monitor.sh         # Monitor resources
├── adf-pipelines/         # Data Factory definitions
│   ├── pipeline_onprem_to_cloud_etl.json
│   ├── dataset_onprem_csv.json
│   ├── dataset_blob_raw.json
│   ├── dataset_blob_archive.json
│   ├── dataset_sql_employees.json
│   └── sql_setup.sql
├── sample-data/           # Sample CSV files
├── docs/                  # Documentation
└── README.md             # This file
```

## 💰 Cost Management

### Estimated Monthly Costs (24/7 operation)

| Service | Size/SKU | Est. Cost |
|---------|----------|-----------|
| Windows VM | Standard_D2s_v3 | ~$70-90 |
| Storage Account | Standard LRS | ~$2-5 |
| SQL Database | Basic | ~$5 |
| Data Factory | Pay per execution | Variable |
| **Total** | | **~$80-100/month** |

### Cost Optimization

1. **Auto-Shutdown**: VM automatically shuts down at 7 PM daily
2. **Deallocate VM**: When not in use
   ```bash
   az vm deallocate -g rg-azure-etl-project -n <vm-name>
   ```
3. **Monitor Usage**:
   ```bash
   ./scripts/monitor.sh
   ```
4. **Clean Up**: Destroy all resources when done
   ```bash
   ./scripts/cleanup.sh
   ```

## 🔐 Security Features

- ✅ All credentials stored in Azure Key Vault
- ✅ Managed Identity for Data Factory
- ✅ Network Security Groups for VM
- ✅ Private networking (can be extended)
- ✅ HTTPS-only communication
- ✅ IP whitelisting for Key Vault and SQL
- ✅ Soft delete enabled on Key Vault

## 🔧 Common Operations

### Monitor Resources
```bash
./scripts/monitor.sh
```

### Get VM Password
```bash
az keyvault secret show --vault-name <kv-name> --name vm-admin-password --query value -o tsv
```

### Check SHIR Status
```bash
# In Azure Portal
Data Factory → Manage → Integration Runtimes
```

### Test Pipeline
```bash
# In Azure Portal
Data Factory → Author → Pipelines → OnPrem_to_Azure_ETL_Pipeline → Debug
```

## 📊 Data Flow

1. **Source**: CSV files in `C:\OnPremiseData` on VM
2. **Landing**: Azure Blob Storage → `raw-data` container
3. **Processing**: Azure Data Factory transformation
4. **Target**: Azure SQL Database → `dbo.Employees` table
5. **Archive**: Azure Blob Storage → `archive-data` container (dated folders)

## 🔄 Pipeline Schedule

The ETL pipeline can be scheduled to run:
- Hourly
- Daily at specific time
- Event-driven (file arrival)
- Manual trigger

Configure in Data Factory → Triggers

## 🐛 Troubleshooting

### SHIR Not Connecting
- Check VM is running: `./scripts/monitor.sh`
- Verify authentication key: `./scripts/get-shir-key.sh`
- Check firewall rules on VM
- Ensure HTTPS (443) outbound is allowed

### Pipeline Failures
- Check Data Factory Monitor tab
- Verify linked service connections
- Confirm credentials in Key Vault
- Check source files exist

### SQL Connection Issues
- Verify firewall rules include your IP
- Check connection string in Key Vault
- Ensure SQL Database is online

## 📝 Git Integration

### Initialize Local Repository

```bash
cd /Users/user/Desktop/Development/azure-etl-project
git init
git add .
git commit -m "Initial commit: Azure ETL project"
```

### Push to GitHub

```bash
git remote add origin https://github.com/YOUR_USERNAME/azure-etl-project.git
git branch -M main
git push -u origin main
```

### Update Data Factory Git Integration

After pushing to GitHub, update [terraform/datafactory.tf](terraform/datafactory.tf):
- Set your GitHub account name
- Set your repository name
- Redeploy with `./scripts/deploy.sh`

## 🧹 Cleanup

When you're done with the project:

```bash
./scripts/cleanup.sh
```

This will:
- Destroy all Azure resources
- Remove Terraform state
- Clean up local files

⚠️ **Warning**: This is irreversible!

## 📚 Learn More

- [Azure Data Factory Documentation](https://docs.microsoft.com/azure/data-factory/)
- [Self-Hosted Integration Runtime](https://docs.microsoft.com/azure/data-factory/concepts-integration-runtime)
- [Azure Key Vault](https://docs.microsoft.com/azure/key-vault/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

## 🤝 Contributing

This is a personal learning/portfolio project. Feel free to fork and adapt for your own use.

## 📄 License

MIT License - See LICENSE file for details

## 👤 Author

Your Name - Azure Cloud Engineer

---

**Built with** ❤️ **using Terraform and Azure**
