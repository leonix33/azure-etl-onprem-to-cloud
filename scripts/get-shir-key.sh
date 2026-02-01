#!/bin/bash

# Get SHIR Authentication Key
# This script retrieves the SHIR key from Terraform outputs

cd "$(dirname "$0")/../terraform"

if [ ! -f "terraform.tfstate" ]; then
    echo "❌ No terraform state found. Please deploy infrastructure first."
    exit 1
fi

echo "========================================="
echo "SHIR Authentication Key"
echo "========================================="
echo ""

SHIR_KEY=$(terraform output -raw shir_auth_key_primary 2>/dev/null)

if [ -z "$SHIR_KEY" ]; then
    echo "❌ Could not retrieve SHIR key. Please ensure infrastructure is deployed."
    exit 1
fi

echo "Primary Key:"
echo "$SHIR_KEY"
echo ""
echo "Copy this key to register SHIR on the VM."
echo ""
echo "Download SHIR:"
echo "https://www.microsoft.com/en-us/download/details.aspx?id=39717"
echo ""
