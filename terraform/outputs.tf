output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.etl_rg.name
}

output "vm_public_ip" {
  description = "Public IP address of the SHIR VM"
  value       = azurerm_public_ip.vm_pip.ip_address
}

output "vm_name" {
  description = "Name of the SHIR VM"
  value       = azurerm_windows_virtual_machine.shir_vm.name
}

output "vm_admin_username" {
  description = "Admin username for the VM"
  value       = var.vm_admin_username
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.etl_kv.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.etl_kv.vault_uri
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.etl_storage.name
}

output "storage_account_primary_endpoint" {
  description = "Primary blob endpoint"
  value       = azurerm_storage_account.etl_storage.primary_blob_endpoint
}

output "data_factory_name" {
  description = "Name of the Data Factory"
  value       = azurerm_data_factory.etl_adf.name
}

output "data_factory_id" {
  description = "ID of the Data Factory"
  value       = azurerm_data_factory.etl_adf.id
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.etl_logs.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.etl_logs.name
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.etl_insights.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Application Insights connection string"
  value       = azurerm_application_insights.etl_insights.connection_string
  sensitive   = true
}

output "databricks_workspace_url" {
  description = "URL of the Databricks workspace"
  value       = "https://${azurerm_databricks_workspace.etl_databricks.workspace_url}"
}

output "databricks_workspace_id" {
  description = "ID of the Databricks workspace"
  value       = azurerm_databricks_workspace.etl_databricks.id
}


output "shir_name" {
  description = "Name of the Self-Hosted Integration Runtime"
  value       = azurerm_data_factory_integration_runtime_self_hosted.shir.name
}

output "shir_auth_key_primary" {
  description = "Primary authentication key for SHIR"
  value       = azurerm_data_factory_integration_runtime_self_hosted.shir.primary_authorization_key
  sensitive   = true
}

output "shir_auth_key_secondary" {
  description = "Secondary authentication key for SHIR"
  value       = azurerm_data_factory_integration_runtime_self_hosted.shir.secondary_authorization_key
  sensitive   = true
}

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the SQL Server"
  value       = azurerm_mssql_server.etl_sql.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "Name of the SQL Database"
  value       = azurerm_mssql_database.etl_db.name
}

output "deployment_instructions" {
  description = "Next steps for deployment"
  value       = <<-EOT
    ========================================
    Azure ETL Project - Deployment Complete
    ========================================
    
    Next Steps:
    1. RDP to VM: ${azurerm_public_ip.vm_pip.ip_address}
       Username: ${var.vm_admin_username}
       Password: (stored in Key Vault: ${azurerm_key_vault.etl_kv.name})
    
    2. Install SHIR on the VM:
       - Run: cd /Users/user/Desktop/Development/azure-etl-project/scripts
       - Execute: ./get-shir-key.sh
       - Download SHIR: https://www.microsoft.com/en-us/download/details.aspx?id=39717
       - Install and register with the key shown above
    
    3. Upload sample data to VM: ${var.source_data_path}
    
    4. Configure ADF pipelines:
       - Navigate to: https://adf.azure.com
       - Open: ${azurerm_data_factory.etl_adf.name}
    
    5. Test the ETL pipeline
    
    Resources Created:
    - Resource Group: ${azurerm_resource_group.etl_rg.name}
    - VM: ${azurerm_windows_virtual_machine.shir_vm.name}
    - Storage: ${azurerm_storage_account.etl_storage.name}
    - Key Vault: ${azurerm_key_vault.etl_kv.name}
    - Data Factory: ${azurerm_data_factory.etl_adf.name}
    - SQL Server: ${azurerm_mssql_server.etl_sql.fully_qualified_domain_name}
    
    Clean up: terraform destroy -auto-approve
    ========================================
  EOT
}
