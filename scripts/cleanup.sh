#!/bin/bash

# Cleanup Azure ETL Infrastructure
# This script destroys all Azure resources

set -e

echo "========================================="
echo "Azure ETL Project - Infrastructure Cleanup"
echo "========================================="
echo ""
echo "⚠️  WARNING: This will destroy ALL resources!"
echo ""

# Change to terraform directory
cd "$(dirname "$0")/../terraform"

# Check if Azure CLI is installed and logged in
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed."
    exit 1
fi

echo "✅ Checking Azure authentication..."
if ! az account show &> /dev/null; then
    echo "❌ Not logged into Azure. Running 'az login'..."
    az login
fi

SUBSCRIPTION=$(az account show --query name -o tsv)
echo "✅ Using subscription: $SUBSCRIPTION"

# List resources that will be destroyed
echo ""
echo "📋 Resources to be destroyed:"
terraform state list

# Ask for confirmation
echo ""
read -p "Are you sure you want to destroy all resources? Type 'destroy' to confirm: " CONFIRM

if [ "$CONFIRM" != "destroy" ]; then
    echo "❌ Cleanup cancelled."
    exit 0
fi

# Double confirmation
echo ""
read -p "Final confirmation - Type 'yes' to proceed: " FINAL_CONFIRM

if [ "$FINAL_CONFIRM" != "yes" ]; then
    echo "❌ Cleanup cancelled."
    exit 0
fi

# Destroy infrastructure
echo ""
echo "🗑️  Destroying infrastructure..."
terraform destroy -auto-approve

# Clean up local files
echo ""
echo "🧹 Cleaning up local files..."
rm -f tfplan
rm -f ../deployment-outputs.json
rm -f ../DEPLOYMENT_INFO.txt
rm -f ../scripts/shir-key.txt
rm -rf .terraform.lock.hcl

echo ""
echo "========================================="
echo "✅ Cleanup Complete!"
echo "========================================="
echo ""
echo "All Azure resources have been destroyed."
echo ""
