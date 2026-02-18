#!/bin/bash
# Setup script for Key Vault Secret Monitoring Dashboard

set -e

echo "🔐 Azure Key Vault Secret Monitoring Setup"
echo "=========================================="
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install it first:"
    echo "   https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install it first."
    exit 1
fi

echo "✅ Prerequisites check passed"
echo ""

# Get Azure subscription and login
echo "📋 Checking Azure login status..."
if ! az account show &> /dev/null; then
    echo "Please login to Azure..."
    az login
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
echo "✅ Logged in to subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
echo ""

# Prompt for resource group
read -p "Enter Resource Group name: " RESOURCE_GROUP

# Validate resource group exists
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    echo "❌ Resource group $RESOURCE_GROUP not found"
    exit 1
fi

echo "✅ Resource group found: $RESOURCE_GROUP"
echo ""

# Find Key Vault in resource group
echo "🔍 Finding Key Vault in resource group..."
KEY_VAULT_NAME=$(az keyvault list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)

if [ -z "$KEY_VAULT_NAME" ]; then
    echo "❌ No Key Vault found in resource group $RESOURCE_GROUP"
    exit 1
fi

echo "✅ Found Key Vault: $KEY_VAULT_NAME"
echo ""

# Find or create Log Analytics workspace
echo "🔍 Looking for Log Analytics workspace..."
WORKSPACE_NAME=$(az monitor log-analytics workspace list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)

if [ -z "$WORKSPACE_NAME" ]; then
    echo "⚠️  No Log Analytics workspace found"
    read -p "Would you like to create one? (y/n): " CREATE_WORKSPACE
    
    if [ "$CREATE_WORKSPACE" = "y" ]; then
        WORKSPACE_NAME="log-etl-monitoring"
        echo "Creating Log Analytics workspace: $WORKSPACE_NAME"
        az monitor log-analytics workspace create \
            --resource-group "$RESOURCE_GROUP" \
            --workspace-name "$WORKSPACE_NAME" \
            --location "$(az group show --name "$RESOURCE_GROUP" --query location -o tsv)"
        echo "✅ Created workspace: $WORKSPACE_NAME"
    else
        echo "❌ Log Analytics workspace is required for the dashboard"
        exit 1
    fi
else
    echo "✅ Found workspace: $WORKSPACE_NAME"
fi

WORKSPACE_ID=$(az monitor log-analytics workspace show \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$WORKSPACE_NAME" \
    --query customerId -o tsv)

WORKSPACE_RESOURCE_ID=$(az monitor log-analytics workspace show \
    --resource-group "$RESOURCE_GROUP" \
    --workspace-name "$WORKSPACE_NAME" \
    --query id -o tsv)

echo ""

# Enable diagnostic settings for Key Vault
echo "🔧 Configuring Key Vault diagnostic settings..."

# Check if diagnostic settings already exist
DIAG_EXISTS=$(az monitor diagnostic-settings list \
    --resource "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEY_VAULT_NAME" \
    --query "[?name=='keyvault-diagnostics'] | length(@)" -o tsv)

if [ "$DIAG_EXISTS" = "0" ]; then
    echo "Creating diagnostic settings..."
    az monitor diagnostic-settings create \
        --name "keyvault-diagnostics" \
        --resource "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEY_VAULT_NAME" \
        --workspace "$WORKSPACE_RESOURCE_ID" \
        --logs '[{"category": "AuditEvent", "enabled": true}, {"category": "AzurePolicyEvaluationDetails", "enabled": true}]' \
        --metrics '[{"category": "AllMetrics", "enabled": true}]'
    echo "✅ Diagnostic settings configured"
else
    echo "✅ Diagnostic settings already exist"
fi

echo ""

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip3 install -q azure-identity azure-keyvault-secrets tabulate requests
echo "✅ Python dependencies installed"
echo ""

# Run initial secret check
echo "🔍 Running initial Key Vault secret check..."
echo ""

python3 scripts/check-keyvault-secrets.py --vault-name "$KEY_VAULT_NAME" || true

echo ""
read -p "Would you like to send this data to Log Analytics for the dashboard? (y/n): " SEND_TO_LA

if [ "$SEND_TO_LA" = "y" ]; then
    echo "Getting Log Analytics workspace key..."
    WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
        --resource-group "$RESOURCE_GROUP" \
        --workspace-name "$WORKSPACE_NAME" \
        --query primarySharedKey -o tsv)
    
    echo "Sending data to Log Analytics..."
    python3 scripts/check-keyvault-secrets.py \
        --vault-name "$KEY_VAULT_NAME" \
        --send-to-loganalytics \
        --workspace-id "$WORKSPACE_ID" \
        --workspace-key "$WORKSPACE_KEY"
    
    echo ""
    echo "✅ Data sent to Log Analytics"
    echo "   You can now query using: KeyVaultSecretExpiry_CL"
fi

echo ""
echo "📊 Setting up Azure Workbook Dashboard..."
echo ""
echo "To deploy the dashboard:"
echo "1. Go to: https://portal.azure.com/#blade/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade/workbooks"
echo "2. Click '+ New'"
echo "3. Click '</> Advanced Editor' in the top toolbar"
echo "4. Copy the contents of: monitoring/keyvault-dashboard.json"
echo "5. Update fallbackResourceIds at the bottom to:"
echo "   $WORKSPACE_RESOURCE_ID"
echo "6. Click 'Apply' and then 'Done Editing'"
echo "7. Click 'Save' and give it a name"
echo ""

# Create a helper script for future runs
cat > scripts/run-keyvault-check.sh << EOF
#!/bin/bash
# Quick script to check Key Vault secrets and send to Log Analytics

python3 scripts/check-keyvault-secrets.py \\
    --vault-name "$KEY_VAULT_NAME" \\
    --send-to-loganalytics \\
    --workspace-id "$WORKSPACE_ID" \\
    --workspace-key "\$WORKSPACE_KEY"
EOF

chmod +x scripts/run-keyvault-check.sh

echo "✅ Created helper script: scripts/run-keyvault-check.sh"
echo ""

# Summary
echo "🎉 Setup Complete!"
echo "================="
echo ""
echo "📋 Configuration Summary:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Key Vault: $KEY_VAULT_NAME"
echo "  Log Analytics: $WORKSPACE_NAME"
echo "  Workspace ID: $WORKSPACE_ID"
echo ""
echo "🚀 Next Steps:"
echo "  1. Deploy the Azure Workbook dashboard (instructions above)"
echo "  2. Run: scripts/run-keyvault-check.sh (to update dashboard data)"
echo "  3. Schedule the script to run daily (cron/Azure Automation)"
echo "  4. Review the dashboard at: Azure Portal → Monitor → Workbooks"
echo ""
echo "📖 Full documentation: monitoring/README_KEYVAULT.md"
echo ""
