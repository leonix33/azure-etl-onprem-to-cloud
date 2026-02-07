# Azure ETL Project Architecture

## Overview

This document provides detailed architectural information about the Azure ETL project.

## Architecture Diagram

### High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                         ON-PREMISE LAYER                              │
│                                                                       │
│  ┌─────────────────┐          ┌──────────────────────────┐          │
│  │                 │          │                           │          │
│  │  Data Sources   │─────────>│   Windows VM (SHIR Host) │          │
│  │  - CSV Files    │          │   - Integration Runtime   │          │
│  │  - Databases    │          │   - Data Collectors       │          │
│  │  - Applications │          │   - Local Cache           │          │
│  │                 │          │                           │          │
│  └─────────────────┘          └──────────┬───────────────┘          │
│                                           │                           │
└───────────────────────────────────────────┼───────────────────────────┘
                                            │
                                  Secure HTTPS (443)
                                  TLS 1.2+ Encrypted
                                            │
                                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│                          AZURE CLOUD LAYER                            │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │                   SECURITY & IDENTITY                            │ │
│  │  ┌──────────────────┐        ┌───────────────────────┐          │ │
│  │  │  Azure Key Vault │        │  Managed Identities   │          │ │
│  │  │  - Secrets       │◀──────│  - Data Factory MI    │          │ │
│  │  │  - Conn Strings  │        │  - VM System MI       │          │ │
│  │  └──────────────────┘        └───────────────────────┘          │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                                    │                                  │
│                                    ▼                                  │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │                  ORCHESTRATION LAYER                             │ │
│  │                                                                  │ │
│  │              ┌────────────────────────────┐                     │ │
│  │              │  Azure Data Factory        │                     │ │
│  │              │  ┌──────────────────────┐  │                     │ │
│  │              │  │  Pipelines          │  │                     │ │
│  │              │  │  - Copy Activity    │  │                     │ │
│  │              │  │  - Transform        │  │                     │ │
│  │              │  │  - Archive          │  │                     │ │
│  │              │  └──────────────────────┘  │                     │ │
│  │              │  ┌──────────────────────┐  │                     │ │
│  │              │  │  Linked Services    │  │                     │ │
│  │              │  │  - SHIR Connection  │  │                     │ │
│  │              │  │  - Storage Account  │  │                     │ │
│  │              │  │  - SQL Database     │  │                     │ │
│  │              │  └──────────────────────┘  │                     │ │
│  │              └────────────────────────────┘                     │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                          │                    │                       │
│             ┌────────────┴────────┐    ┌──────┴──────┐              │
│             ▼                     ▼    ▼             ▼              │
│  ┌─────────────────────┐  ┌────────────────────────────────┐       │
│  │  STORAGE LAYER      │  │     DATA PROCESSING LAYER      │       │
│  │                     │  │                                 │       │
│  │  Blob Storage       │  │  Azure SQL Database             │       │
│  │  (Data Lake Gen2)   │  │  ┌──────────────────────────┐  │       │
│  │  ┌───────────────┐  │  │  │  dbo.Employees          │  │       │
│  │  │ raw-data/     │  │  │  │  - Primary Key          │  │       │
│  │  │ - Landing     │  │  │  │  - Indexes              │  │       │
│  │  └───────────────┘  │  │  │  - Audit Columns        │  │       │
│  │  ┌───────────────┐  │  │  └──────────────────────────┘  │       │
│  │  │ processed/    │  │  │  ┌──────────────────────────┐  │       │
│  │  │ - Transformed │  │  │  │  Views & Aggregations   │  │       │
│  │  └───────────────┘  │  │  │  - Department Summary   │  │       │
│  │  ┌───────────────┐  │  │  │  - Latest Records       │  │       │
│  │  │ archive/      │  │  │  └──────────────────────────┘  │       │
│  │  │ - Historical  │  │  │                                 │       │
│  │  └───────────────┘  │  └─────────────────────────────────┘       │
│  └─────────────────────┘                                             │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

## Data Flow

### ETL Pipeline Flow

1. **Extract Phase**
   - Source: On-premise file system (`C:\OnPremiseData`)
   - Format: CSV files with employee data
   - Transport: SHIR secure connection
   - Destination: Azure Blob Storage (raw-data container)

2. **Transform Phase**
   - Source: Blob Storage raw-data
   - Operations:
     - Data type conversion
     - Validation
     - Deduplication (upsert by EmployeeID)
     - Add audit columns (LoadedDate)
   - Destination: Azure SQL Database

3. **Archive Phase**
   - Source: Blob Storage raw-data
   - Operations:
     - Copy with date-based folder structure (YYYY/MM/DD)
     - Retention policy ready
   - Destination: Blob Storage archive-data

## AI Layer (RAG)

```
ADLS Gen2 (processed-data)
   └── Azure AI Search (index + indexer)
         └── Azure OpenAI (Q&A over retrieved context)
```

### RAG Flow

1. Documents in `processed-data` are indexed by Azure AI Search
2. Search retrieves top‑K results for a query
3. Azure OpenAI uses retrieved context to answer questions

## Network Architecture

```
┌─────────────────────────────────────────────────────┐
│  Virtual Network (10.0.0.0/16)                      │
│                                                      │
│  ┌────────────────────────────────────────────┐    │
│  │  VM Subnet (10.0.1.0/24)                   │    │
│  │  ┌──────────────────────────────────┐      │    │
│  │  │  SHIR VM                          │      │    │
│  │  │  - Private IP: 10.0.1.x          │      │    │
│  │  │  - Public IP: Dynamic (NAT)       │      │    │
│  │  │  - NSG: RDP, HTTPS Outbound       │      │    │
│  │  └──────────────────────────────────┘      │    │
│  └────────────────────────────────────────────┘    │
│                                                      │
└─────────────────────────────────────────────────────┘
                      │
                      │ Outbound to Azure Services
                      │ (Storage, SQL, Data Factory)
                      ▼
        ┌─────────────────────────────┐
        │  Azure Backbone Network     │
        │  - Private endpoints ready  │
        └─────────────────────────────┘
```

## Security Architecture

### Identity & Access Management

```
┌──────────────────────────────────────────────────────┐
│  Azure Active Directory                              │
│  ┌────────────────────────────────────────────────┐ │
│  │  Service Principals & Managed Identities       │ │
│  │                                                 │ │
│  │  ┌──────────────────────────────────┐          │ │
│  │  │  Data Factory Managed Identity   │          │ │
│  │  │  - Key Vault: Get/List Secrets   │          │ │
│  │  │  - Storage: Contributor          │          │ │
│  │  │  - SQL: db_datareader/writer     │          │ │
│  │  └──────────────────────────────────┘          │ │
│  │                                                 │ │
│  │  ┌──────────────────────────────────┐          │ │
│  │  │  VM System Assigned MI           │          │ │
│  │  │  - Key Vault: Get Secrets        │          │ │
│  │  └──────────────────────────────────┘          │ │
│  └────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘
```

### Secret Management

All sensitive data stored in Azure Key Vault:
- VM admin password
- Storage connection strings
- SQL connection strings
- SHIR authentication keys

### Network Security

- **NSG Rules**:
  - Inbound: RDP (3389) from allowed IPs only
  - Outbound: HTTPS (443, 80) to Azure services
  
- **Key Vault**:
  - Network ACL: Allow Azure services
  - Option to restrict to specific IPs
  
- **SQL Database**:
  - Firewall rules for allowed IPs
  - Azure services access enabled

## Resource Dependencies

```
random_string (suffix)
    │
    ├──> Resource Group
    │       │
    │       ├──> Virtual Network
    │       │       │
    │       │       ├──> Subnet
    │       │       │       │
    │       │       │       └──> Network Interface
    │       │       │               │
    │       │       │               └──> VM
    │       │       │
    │       │       └──> NSG
    │       │
    │       ├──> Storage Account
    │       │       │
    │       │       ├──> Container: raw-data
    │       │       ├──> Container: processed-data
    │       │       └──> Container: archive-data
    │       │
    │       ├──> SQL Server
    │       │       │
    │       │       └──> SQL Database
    │       │
    │       ├──> Key Vault
    │       │       │
    │       │       └──> Secrets
    │       │
    │       └──> Data Factory
    │               │
    │               ├──> SHIR
    │               ├──> Linked Services
    │               ├──> Datasets
    │               └──> Pipelines
```

## Scalability Considerations

### Current Configuration
- VM: Standard_D2s_v3 (2 vCPU, 8 GB RAM)
- Storage: Standard LRS
- SQL: Basic tier (2 GB)
- Data Factory: Pay-per-use

### Scale-Up Options
- **VM**: Increase to D4s, D8s for more data volume
- **Storage**: Premium or Zone-redundant for higher IOPS
- **SQL**: Scale to Standard (S2, S3) or Premium
- **Parallel Processing**: Multiple SHIR nodes

## Disaster Recovery

### Backup Strategy
- **Blob Storage**: Versioning enabled, 7-day retention
- **SQL Database**: Automatic backups (7 days)
- **Key Vault**: Soft delete enabled (7 days)
- **Infrastructure**: Terraform state for recreation

### Recovery Procedures
1. Infrastructure: `terraform apply` from state
2. Data: Restore from blob versions or SQL backups
3. Secrets: Recover from Key Vault soft delete

## Monitoring & Logging

### Available Metrics
- **Data Factory**: Pipeline runs, activity runs, trigger runs
- **VM**: CPU, memory, disk, network
- **Storage**: Transactions, latency, availability
- **SQL**: DTU usage, queries, connections

### Logging
- **Activity Logs**: All Azure resource changes
- **Diagnostic Logs**: Can be enabled for detailed logging
- **Pipeline Logs**: Copy activity details, row counts, errors

## Cost Optimization

### Implemented Strategies
1. **Auto-shutdown**: VM at 7 PM daily
2. **Basic Tier**: SQL and Storage for dev/test
3. **LRS Storage**: Local redundancy only
4. **Pay-per-use**: Data Factory execution-based pricing

### Further Optimizations
1. Reserved instances for production
2. Archive tier for old blob data
3. Spot VMs for non-critical workloads
4. Scheduled scaling

---

*Last Updated: January 31, 2026*
