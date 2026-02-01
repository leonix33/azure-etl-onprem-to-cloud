#!/bin/bash

# Monitor Azure Resources and Costs

cd "$(dirname "$0")/../terraform"

if [ ! -f "terraform.tfstate" ]; then
    echo "❌ No terraform state found. Please deploy infrastructure first."
    exit 1
fi

echo "========================================="
echo "Azure ETL Project - Resource Monitor"
echo "========================================="
echo ""

RG_NAME=$(terraform output -raw resource_group_name 2>/dev/null)

if [ -z "$RG_NAME" ]; then
    echo "❌ Could not retrieve resource group name."
    exit 1
fi

echo "Resource Group: $RG_NAME"
echo ""

# List all resources
echo "📋 Resources:"
az resource list --resource-group "$RG_NAME" --output table

echo ""
echo "💰 Estimated Monthly Costs:"
echo "   - VM (Standard_D2s_v3): ~\$70-90/month"
echo "   - Storage Account: ~\$2-5/month"
echo "   - SQL Database (Basic): ~\$5/month"
echo "   - Data Factory: Pay per execution"
echo "   --------------------------------"
echo "   Total: ~\$80-100/month (if running 24/7)"
echo ""
echo "💡 Cost Optimization Tips:"
echo "   - VM auto-shuts down at 7 PM daily"
echo "   - Stop VM when not in use: az vm deallocate -g $RG_NAME -n <vm-name>"
echo "   - Use 'cleanup.sh' to destroy all resources when done"
echo ""

# VM Status
echo "🖥️  VM Status:"
VM_NAME=$(terraform output -raw vm_name 2>/dev/null)
az vm get-instance-view --resource-group "$RG_NAME" --name "$VM_NAME" --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" -o tsv

echo ""
