#!/usr/bin/env python3
"""
Azure Key Vault Secret Expiration Checker
==========================================

This script checks all secrets in Azure Key Vault and reports on their expiration status.
It can send results to Log Analytics for dashboard visualization.

Usage:
    python check-keyvault-secrets.py --vault-name <vault-name> [--send-to-loganalytics]
    
Requirements:
    pip install azure-identity azure-keyvault-secrets azure-monitor-ingestion tabulate
"""

import argparse
import sys
from datetime import datetime, timezone, timedelta
from typing import List, Dict, Optional
import json

try:
    from azure.identity import DefaultAzureCredential, AzureCliCredential
    from azure.keyvault.secrets import SecretClient, SecretProperties
    from tabulate import tabulate
except ImportError as e:
    print(f"Error: Missing required package. Install with: pip install azure-identity azure-keyvault-secrets tabulate")
    print(f"Details: {e}")
    sys.exit(1)


class SecretExpirationStatus:
    """Enumeration for secret expiration status levels"""
    EXPIRED = "EXPIRED"
    CRITICAL = "CRITICAL"  # <= 7 days
    WARNING = "WARNING"    # <= 30 days
    NOTICE = "NOTICE"      # <= 90 days
    OK = "OK"
    NO_EXPIRY = "NO_EXPIRY"


class KeyVaultSecretChecker:
    """Check Azure Key Vault secrets for expiration"""
    
    def __init__(self, vault_name: str):
        """
        Initialize the Key Vault Secret Checker
        
        Args:
            vault_name: Name of the Azure Key Vault
        """
        self.vault_name = vault_name
        self.vault_url = f"https://{vault_name}.vault.azure.net"
        
        # Try to authenticate using Azure CLI credentials first, then default
        try:
            self.credential = AzureCliCredential()
            self.client = SecretClient(vault_url=self.vault_url, credential=self.credential)
        except Exception:
            self.credential = DefaultAzureCredential()
            self.client = SecretClient(vault_url=self.vault_url, credential=self.credential)
    
    def get_expiration_status(self, expiry_date: Optional[datetime]) -> str:
        """
        Determine the expiration status of a secret
        
        Args:
            expiry_date: The expiration date of the secret
            
        Returns:
            Status string (EXPIRED, CRITICAL, WARNING, NOTICE, OK, NO_EXPIRY)
        """
        if expiry_date is None:
            return SecretExpirationStatus.NO_EXPIRY
        
        now = datetime.now(timezone.utc)
        days_until_expiry = (expiry_date - now).days
        
        if days_until_expiry < 0:
            return SecretExpirationStatus.EXPIRED
        elif days_until_expiry <= 7:
            return SecretExpirationStatus.CRITICAL
        elif days_until_expiry <= 30:
            return SecretExpirationStatus.WARNING
        elif days_until_expiry <= 90:
            return SecretExpirationStatus.NOTICE
        else:
            return SecretExpirationStatus.OK
    
    def get_status_emoji(self, status: str) -> str:
        """Get emoji representation for status"""
        emoji_map = {
            SecretExpirationStatus.EXPIRED: "🔴",
            SecretExpirationStatus.CRITICAL: "🟠",
            SecretExpirationStatus.WARNING: "🟡",
            SecretExpirationStatus.NOTICE: "🔵",
            SecretExpirationStatus.OK: "🟢",
            SecretExpirationStatus.NO_EXPIRY: "⚪"
        }
        return emoji_map.get(status, "❓")
    
    def check_all_secrets(self) -> List[Dict]:
        """
        Check all secrets in the Key Vault
        
        Returns:
            List of dictionaries containing secret information
        """
        secrets_info = []
        
        print(f"\n🔍 Scanning Key Vault: {self.vault_name}")
        print("=" * 80)
        
        try:
            # List all secrets
            secret_properties = self.client.list_properties_of_secrets()
            
            for secret_property in secret_properties:
                secret_name = secret_property.name
                expiry_date = secret_property.expires_on
                enabled = secret_property.enabled
                created_on = secret_property.created_on
                updated_on = secret_property.updated_on
                
                # Calculate days until expiry
                if expiry_date:
                    now = datetime.now(timezone.utc)
                    days_until_expiry = (expiry_date - now).days
                else:
                    days_until_expiry = None
                
                # Get status
                status = self.get_expiration_status(expiry_date)
                
                secret_info = {
                    'name': secret_name,
                    'enabled': enabled,
                    'status': status,
                    'expiry_date': expiry_date,
                    'days_until_expiry': days_until_expiry,
                    'created_on': created_on,
                    'updated_on': updated_on,
                    'vault_name': self.vault_name
                }
                
                secrets_info.append(secret_info)
            
            print(f"✅ Found {len(secrets_info)} secret(s)\n")
            
        except Exception as e:
            print(f"❌ Error accessing Key Vault: {e}")
            sys.exit(1)
        
        return secrets_info
    
    def print_summary(self, secrets: List[Dict]):
        """Print a summary of secret expiration status"""
        
        # Count by status
        status_counts = {
            SecretExpirationStatus.EXPIRED: 0,
            SecretExpirationStatus.CRITICAL: 0,
            SecretExpirationStatus.WARNING: 0,
            SecretExpirationStatus.NOTICE: 0,
            SecretExpirationStatus.OK: 0,
            SecretExpirationStatus.NO_EXPIRY: 0
        }
        
        for secret in secrets:
            status_counts[secret['status']] += 1
        
        print("\n📊 EXPIRATION STATUS SUMMARY")
        print("=" * 80)
        summary_table = [
            [self.get_status_emoji(SecretExpirationStatus.EXPIRED), "Expired", status_counts[SecretExpirationStatus.EXPIRED]],
            [self.get_status_emoji(SecretExpirationStatus.CRITICAL), "Critical (≤7 days)", status_counts[SecretExpirationStatus.CRITICAL]],
            [self.get_status_emoji(SecretExpirationStatus.WARNING), "Warning (≤30 days)", status_counts[SecretExpirationStatus.WARNING]],
            [self.get_status_emoji(SecretExpirationStatus.NOTICE), "Notice (≤90 days)", status_counts[SecretExpirationStatus.NOTICE]],
            [self.get_status_emoji(SecretExpirationStatus.OK), "OK (>90 days)", status_counts[SecretExpirationStatus.OK]],
            [self.get_status_emoji(SecretExpirationStatus.NO_EXPIRY), "No Expiry Set", status_counts[SecretExpirationStatus.NO_EXPIRY]]
        ]
        print(tabulate(summary_table, headers=["", "Status", "Count"], tablefmt="grid"))
        print()
    
    def print_detailed_report(self, secrets: List[Dict], show_all: bool = False):
        """Print detailed report of secrets"""
        
        # Filter secrets that need attention (unless show_all is True)
        if not show_all:
            secrets_to_show = [s for s in secrets if s['status'] in [
                SecretExpirationStatus.EXPIRED,
                SecretExpirationStatus.CRITICAL,
                SecretExpirationStatus.WARNING,
                SecretExpirationStatus.NOTICE
            ]]
            title = "⚠️  SECRETS REQUIRING ATTENTION"
        else:
            secrets_to_show = secrets
            title = "📋 ALL SECRETS"
        
        if not secrets_to_show:
            print("\n✅ No secrets require immediate attention!")
            return
        
        print(f"\n{title}")
        print("=" * 80)
        
        # Sort by days until expiry (showing most urgent first)
        secrets_to_show.sort(key=lambda x: x['days_until_expiry'] if x['days_until_expiry'] is not None else 99999)
        
        table_data = []
        for secret in secrets_to_show:
            emoji = self.get_status_emoji(secret['status'])
            name = secret['name']
            status = secret['status']
            
            if secret['expiry_date']:
                expiry = secret['expiry_date'].strftime('%Y-%m-%d')
                days = f"{secret['days_until_expiry']} days" if secret['days_until_expiry'] >= 0 else "EXPIRED"
            else:
                expiry = "No expiry set"
                days = "N/A"
            
            enabled = "✅" if secret['enabled'] else "❌"
            
            table_data.append([emoji, name, status, expiry, days, enabled])
        
        print(tabulate(table_data, 
                      headers=["", "Secret Name", "Status", "Expiry Date", "Days Remaining", "Enabled"],
                      tablefmt="grid"))
        print()
    
    def export_to_json(self, secrets: List[Dict], output_file: str):
        """Export secrets information to JSON file"""
        
        # Convert datetime objects to strings for JSON serialization
        secrets_serializable = []
        for secret in secrets:
            secret_copy = secret.copy()
            if secret_copy['expiry_date']:
                secret_copy['expiry_date'] = secret_copy['expiry_date'].isoformat()
            if secret_copy['created_on']:
                secret_copy['created_on'] = secret_copy['created_on'].isoformat()
            if secret_copy['updated_on']:
                secret_copy['updated_on'] = secret_copy['updated_on'].isoformat()
            secrets_serializable.append(secret_copy)
        
        with open(output_file, 'w') as f:
            json.dump(secrets_serializable, f, indent=2)
        
        print(f"📄 Report exported to: {output_file}")
    
    def send_to_log_analytics(self, secrets: List[Dict], workspace_id: str, shared_key: str):
        """
        Send secret expiration data to Log Analytics
        
        Args:
            secrets: List of secret information dictionaries
            workspace_id: Log Analytics Workspace ID
            shared_key: Log Analytics Workspace shared key
        """
        try:
            import requests
            import hashlib
            import hmac
            import base64
            
            # Build the API signature
            def build_signature(workspace_id, shared_key, date, content_length, method, content_type, resource):
                x_headers = f'x-ms-date:{date}'
                string_to_hash = f'{method}\n{content_length}\n{content_type}\n{x_headers}\n{resource}'
                bytes_to_hash = bytes(string_to_hash, encoding="utf-8")
                decoded_key = base64.b64decode(shared_key)
                encoded_hash = base64.b64encode(hmac.new(decoded_key, bytes_to_hash, digestmod=hashlib.sha256).digest()).decode()
                authorization = f"SharedKey {workspace_id}:{encoded_hash}"
                return authorization
            
            # Prepare data for Log Analytics
            log_type = "KeyVaultSecretExpiry"
            
            logs = []
            for secret in secrets:
                log_entry = {
                    "SecretName": secret['name'],
                    "KeyVaultName": secret['vault_name'],
                    "Status": secret['status'],
                    "Enabled": secret['enabled'],
                    "DaysUntilExpiry": secret['days_until_expiry'] if secret['days_until_expiry'] is not None else -999,
                    "ExpirationDate": secret['expiry_date'].isoformat() if secret['expiry_date'] else None,
                    "LastUpdated": secret['updated_on'].isoformat() if secret['updated_on'] else None,
                    "CreatedOn": secret['created_on'].isoformat() if secret['created_on'] else None
                }
                logs.append(log_entry)
            
            body = json.dumps(logs)
            
            # Build and send request to Log Analytics
            method = 'POST'
            content_type = 'application/json'
            resource = '/api/logs'
            rfc1123date = datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S GMT')
            content_length = len(body)
            
            signature = build_signature(workspace_id, shared_key, rfc1123date, content_length, method, content_type, resource)
            uri = f'https://{workspace_id}.ods.opinsights.azure.com{resource}?api-version=2016-04-01'
            
            headers = {
                'content-type': content_type,
                'Authorization': signature,
                'Log-Type': log_type,
                'x-ms-date': rfc1123date
            }
            
            response = requests.post(uri, data=body, headers=headers)
            
            if response.status_code >= 200 and response.status_code <= 299:
                print(f"✅ Successfully sent {len(logs)} secret(s) to Log Analytics")
                print(f"   Log Type: {log_type}_CL")
                print(f"   You can query this data in Log Analytics using: {log_type}_CL")
            else:
                print(f"❌ Failed to send to Log Analytics: {response.status_code} - {response.text}")
                
        except ImportError:
            print("❌ 'requests' package required for Log Analytics integration")
            print("   Install with: pip install requests")
        except Exception as e:
            print(f"❌ Error sending to Log Analytics: {e}")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='Check Azure Key Vault secrets for expiration',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Check secrets in a Key Vault
  python check-keyvault-secrets.py --vault-name my-keyvault
  
  # Show all secrets (not just expiring ones)
  python check-keyvault-secrets.py --vault-name my-keyvault --show-all
  
  # Export to JSON
  python check-keyvault-secrets.py --vault-name my-keyvault --output report.json
  
  # Send to Log Analytics for dashboard
  python check-keyvault-secrets.py --vault-name my-keyvault \\
      --send-to-loganalytics \\
      --workspace-id YOUR_WORKSPACE_ID \\
      --workspace-key YOUR_WORKSPACE_KEY
        """
    )
    
    parser.add_argument('--vault-name', required=True, help='Name of the Azure Key Vault')
    parser.add_argument('--show-all', action='store_true', help='Show all secrets, not just expiring ones')
    parser.add_argument('--output', help='Export results to JSON file')
    parser.add_argument('--send-to-loganalytics', action='store_true', help='Send data to Log Analytics')
    parser.add_argument('--workspace-id', help='Log Analytics Workspace ID')
    parser.add_argument('--workspace-key', help='Log Analytics Workspace shared key')
    
    args = parser.parse_args()
    
    # Validate Log Analytics arguments
    if args.send_to_loganalytics:
        if not args.workspace_id or not args.workspace_key:
            print("❌ Error: --workspace-id and --workspace-key are required when using --send-to-loganalytics")
            sys.exit(1)
    
    # Create checker and scan secrets
    checker = KeyVaultSecretChecker(args.vault_name)
    secrets = checker.check_all_secrets()
    
    # Print reports
    checker.print_summary(secrets)
    checker.print_detailed_report(secrets, show_all=args.show_all)
    
    # Export if requested
    if args.output:
        checker.export_to_json(secrets, args.output)
    
    # Send to Log Analytics if requested
    if args.send_to_loganalytics:
        checker.send_to_log_analytics(secrets, args.workspace_id, args.workspace_key)
    
    # Exit with error code if critical secrets found
    critical_count = len([s for s in secrets if s['status'] in [
        SecretExpirationStatus.EXPIRED,
        SecretExpirationStatus.CRITICAL
    ]])
    
    if critical_count > 0:
        print(f"\n⚠️  WARNING: {critical_count} secret(s) are expired or critical!")
        sys.exit(1)
    else:
        print("\n✅ All secrets are OK!")
        sys.exit(0)


if __name__ == '__main__':
    main()
