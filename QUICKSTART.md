# Quick Start - Azure ETL Project

## 🚀 Deploy in 5 Steps

### 1️⃣ Navigate to Project
```bash
cd /Users/user/Desktop/Development/azure-etl-project
```

### 2️⃣ Login to Azure
```bash
az login
az account set --subscription "Azure subscription 1"
```

### 3️⃣ Deploy Infrastructure
```bash
./scripts/deploy.sh
```
⏱️ Takes ~10-15 minutes

### 4️⃣ Setup SHIR
```bash
# Get the SHIR key
./scripts/get-shir-key.sh

# RDP to VM (IP from deployment output)
# Username: azureadmin
# Password: (get from output)

# On VM, run PowerShell as Admin:
.\install-shir.ps1 -AuthKey "<key-from-step-above>"
```

### 5️⃣ Test Pipeline
- Upload `sample-data/employees.csv` to VM: `C:\OnPremiseData\`
- Open Azure Portal → Data Factory
- Run pipeline: `OnPrem_to_Azure_ETL_Pipeline`
- Debug and monitor

## 🧹 Cleanup When Done
```bash
./scripts/cleanup.sh
```

## 📚 Full Documentation
- [README.md](README.md) - Complete overview
- [docs/DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md) - Detailed steps
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - Technical details

## 💰 Cost Estimate
~$80-100/month if running 24/7

**Save Money**:
- VM auto-shuts down at 7 PM daily
- Use `./scripts/cleanup.sh` when done testing
