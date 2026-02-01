#!/bin/bash

# Deploy Azure ETL Infrastructure
# This script deploys all infrastructure using Terraform

set -e

echo "========================================="
echo "Azure ETL Project - Infrastructure Deploy"
echo "========================================="

# Change to terraform directory
cd "$(dirname "$0")/../terraform"

# Check if Azure CLI is installed and logged in
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install it first."
    exit 1
fi

echo "✅ Checking Azure authentication..."
if ! az account show &> /dev/null; then
    echo "❌ Not logged into Azure. Running 'az login'..."
    az login
fi

SUBSCRIPTION=$(az account show --query name -o tsv)
echo "✅ Using subscription: $SUBSCRIPTION"

# Get your public IP for security rules
echo "🔍 Getting your public IP address..."
PUBLIC_IP=$(curl -s https://api.ipify.org)
echo "✅ Your public IP: $PUBLIC_IP"

# Initialize Terraform
echo ""
echo "📦 Initializing Terraform..."
terraform init

# Validate Terraform configuration
echo ""
echo "✅ Validating Terraform configuration..."
terraform validate

# Format Terraform files
echo "🎨 Formatting Terraform files..."
terraform fmt

# Plan the deployment
echo ""
echo "📋 Creating deployment plan..."
terraform plan \
    -var="allowed_ip_addresses=[\"$PUBLIC_IP/32\"]" \
    -out=tfplan

# Ask for confirmation
echo ""
read -p "Do you want to apply this plan? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Deployment cancelled."
    exit 0
fi

# Apply the plan
echo ""
echo "🚀 Deploying infrastructure..."
terraform apply tfplan

# Save outputs
echo ""
echo "📝 Saving deployment outputs..."
terraform output -json > ../deployment-outputs.json
terraform output deployment_instructions > ../DEPLOYMENT_INFO.txt

# Get SHIR keys
echo ""
echo "🔑 Retrieving SHIR authentication keys..."
SHIR_KEY=$(terraform output -raw shir_auth_key_primary)
echo "$SHIR_KEY" > ../scripts/shir-key.txt

echo ""
echo "========================================="
echo "✅ Deployment Complete!"
echo "========================================="
echo ""
echo "📄 Deployment details saved to:"
echo "   - deployment-outputs.json"
echo "   - DEPLOYMENT_INFO.txt"
echo "   - scripts/shir-key.txt"
echo ""
echo "Next steps:"
echo "1. Review DEPLOYMENT_INFO.txt for instructions"
echo "2. RDP to the VM and install SHIR"
echo "3. Configure ADF pipelines"
echo ""
