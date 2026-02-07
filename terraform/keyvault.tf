# Get current Azure client config
data "azurerm_client_config" "current" {}

# Generate random password for VM if not provided
resource "random_password" "vm_password" {
  length  = 16
  special = true
  count   = var.vm_admin_password == null ? 1 : 0
}

# Key Vault for secure credential storage
resource "azurerm_key_vault" "etl_kv" {
  name                       = "kv-etl-${random_string.suffix.result}"
  location                   = azurerm_resource_group.etl_rg.location
  resource_group_name        = azurerm_resource_group.etl_rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  # Enable for Data Factory
  enabled_for_deployment          = true
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow" # Change to "Deny" and add your IP for production
  }

  tags = var.tags
}

# Key Vault Access Policy for current user (Terraform)
resource "azurerm_key_vault_access_policy" "terraform_policy" {
  key_vault_id = azurerm_key_vault.etl_kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get", "List", "Set", "Delete", "Purge", "Recover"
  ]

  key_permissions = [
    "Get", "List", "Create", "Delete", "Purge"
  ]
}

# Key Vault Access Policy for Data Factory
resource "azurerm_key_vault_access_policy" "adf_policy" {
  key_vault_id = azurerm_key_vault.etl_kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_data_factory.etl_adf.identity[0].principal_id

  secret_permissions = [
    "Get", "List"
  ]

  depends_on = [azurerm_data_factory.etl_adf]
}

# Store VM admin password in Key Vault
resource "azurerm_key_vault_secret" "vm_admin_password" {
  name         = "vm-admin-password"
  value        = var.vm_admin_password != null ? var.vm_admin_password : random_password.vm_password[0].result
  key_vault_id = azurerm_key_vault.etl_kv.id

  depends_on = [azurerm_key_vault_access_policy.terraform_policy]
}

# Store Storage Account connection string in Key Vault
resource "azurerm_key_vault_secret" "storage_connection_string" {
  name         = "storage-connection-string"
  value        = azurerm_storage_account.etl_storage.primary_connection_string
  key_vault_id = azurerm_key_vault.etl_kv.id

  depends_on = [azurerm_key_vault_access_policy.terraform_policy]
}

# Store SQL Database connection string (if using SQL)
resource "azurerm_key_vault_secret" "sql_connection_string" {
  name         = "sql-connection-string"
  value        = "Server=tcp:${azurerm_mssql_server.etl_sql.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.etl_db.name};Persist Security Info=False;User ID=${azurerm_mssql_server.etl_sql.administrator_login};Password=${random_password.sql_password.result};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.etl_kv.id

  depends_on = [azurerm_key_vault_access_policy.terraform_policy]
}

# Store Azure AI Search admin key
resource "azurerm_key_vault_secret" "search_admin_key" {
  name         = "ai-search-admin-key"
  value        = azurerm_search_service.etl_search.primary_key
  key_vault_id = azurerm_key_vault.etl_kv.id

  depends_on = [azurerm_key_vault_access_policy.terraform_policy]
}

# Store Azure OpenAI key
resource "azurerm_key_vault_secret" "openai_api_key" {
  name         = "openai-api-key"
  value        = azurerm_cognitive_account.etl_openai.primary_access_key
  key_vault_id = azurerm_key_vault.etl_kv.id

  depends_on = [azurerm_key_vault_access_policy.terraform_policy]
}
