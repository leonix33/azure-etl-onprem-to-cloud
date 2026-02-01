# Azure Data Factory
resource "azurerm_data_factory" "etl_adf" {
  name                = "adf-etl-${var.environment}-${random_string.suffix.result}"
  location            = azurerm_resource_group.etl_rg.location
  resource_group_name = azurerm_resource_group.etl_rg.name

  identity {
    type = "SystemAssigned"
  }

  github_configuration {
    account_name    = "your-github-account" # Update with your GitHub username
    branch_name     = "main"
    git_url         = "https://github.com"
    repository_name = "azure-etl-project" # Update with your repo name
    root_folder     = "/adf-pipelines"
  }

  tags = var.tags
}

# Self-Hosted Integration Runtime
resource "azurerm_data_factory_integration_runtime_self_hosted" "shir" {
  name            = "SHIR-OnPremise"
  data_factory_id = azurerm_data_factory.etl_adf.id

  description = "Self-hosted IR for on-premise data access"
}

# Linked Service - Key Vault
resource "azurerm_data_factory_linked_service_key_vault" "kv_linked" {
  name            = "ls_keyvault"
  data_factory_id = azurerm_data_factory.etl_adf.id
  key_vault_id    = azurerm_key_vault.etl_kv.id

  depends_on = [azurerm_key_vault_access_policy.adf_policy]
}

# Linked Service - Azure Blob Storage
resource "azurerm_data_factory_linked_service_azure_blob_storage" "blob_linked" {
  name            = "ls_azure_blob_storage"
  data_factory_id = azurerm_data_factory.etl_adf.id

  service_endpoint = azurerm_storage_account.etl_storage.primary_blob_endpoint

  key_vault_connection_string {
    linked_service_name = azurerm_data_factory_linked_service_key_vault.kv_linked.name
    secret_name         = azurerm_key_vault_secret.storage_connection_string.name
  }
}

# Linked Service - File System (On-Premise via SHIR)
resource "azurerm_data_factory_linked_service_file_system" "onprem_filesystem" {
  name                     = "ls_onprem_filesystem"
  data_factory_id          = azurerm_data_factory.etl_adf.id
  integration_runtime_name = azurerm_data_factory_integration_runtime_self_hosted.shir.name

  host     = var.source_data_path
  user_id  = var.vm_admin_username
  password = azurerm_key_vault_secret.vm_admin_password.value
}

# Grant Storage Blob Data Contributor role to ADF
resource "azurerm_role_assignment" "adf_storage_contributor" {
  scope                = azurerm_storage_account.etl_storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.etl_adf.identity[0].principal_id
}
