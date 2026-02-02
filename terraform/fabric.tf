# Microsoft Fabric Capacity
resource "azurerm_fabric_capacity" "etl_fabric" {
  name                = "fc-etl-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.etl_rg.name
  location            = azurerm_resource_group.etl_rg.location
  
  sku {
    name = var.fabric_sku
    tier = "Fabric"
  }

  administration {
    members = var.fabric_admin_emails
  }

  tags = var.tags
}

# Store Fabric details in Key Vault
resource "azurerm_key_vault_secret" "fabric_capacity_id" {
  name         = "fabric-capacity-id"
  value        = azurerm_fabric_capacity.etl_fabric.id
  key_vault_id = azurerm_key_vault.etl_kv.id

  depends_on = [azurerm_key_vault_access_policy.terraform_policy]
}

# Grant Fabric access to storage account
resource "azurerm_role_assignment" "fabric_storage_contributor" {
  scope                = azurerm_storage_account.etl_storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_fabric_capacity.etl_fabric.identity[0].principal_id
}

# Grant Fabric access to SQL Database
resource "azurerm_role_assignment" "fabric_sql_contributor" {
  scope                = azurerm_mssql_database.etl_db.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_fabric_capacity.etl_fabric.identity[0].principal_id
}

# Fabric OneLake integration with existing Data Lake
# Note: OneLake shortcuts to ADLS Gen2 are configured in Fabric UI
# This ensures existing data is accessible in Fabric without migration

# Additional storage container for Fabric-specific data
resource "azurerm_storage_container" "fabric_data" {
  name                  = "fabric-data"
  storage_account_name  = azurerm_storage_account.etl_storage.name
  container_access_type = "private"
}

# Create SAS token for Fabric to access storage (stored in Key Vault)
data "azurerm_storage_account_sas" "fabric_sas" {
  connection_string = azurerm_storage_account.etl_storage.primary_connection_string
  https_only        = true
  signed_version    = "2021-06-08"

  resource_types {
    service   = true
    container = true
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  start  = timestamp()
  expiry = timeadd(timestamp(), "8760h") # 1 year

  permissions {
    read    = true
    write   = true
    delete  = true
    list    = true
    add     = true
    create  = true
    update  = true
    process = true
    tag     = false
    filter  = false
  }
}

resource "azurerm_key_vault_secret" "fabric_storage_sas" {
  name         = "fabric-storage-sas"
  value        = data.azurerm_storage_account_sas.fabric_sas.sas
  key_vault_id = azurerm_key_vault.etl_kv.id

  depends_on = [azurerm_key_vault_access_policy.terraform_policy]
}
