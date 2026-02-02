# Azure Databricks Workspace for advanced data transformations
resource "azurerm_databricks_workspace" "etl_databricks" {
  name                = "dbw-etl-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.etl_rg.name
  location            = azurerm_resource_group.etl_rg.location
  sku                 = "standard"

  tags = var.tags
}

# Databricks access connector for Unity Catalog
resource "azurerm_databricks_access_connector" "etl_connector" {
  name                = "dbc-etl-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.etl_rg.name
  location            = azurerm_resource_group.etl_rg.location

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Grant Databricks access to storage account
resource "azurerm_role_assignment" "databricks_storage_contributor" {
  scope                = azurerm_storage_account.etl_storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.etl_connector.identity[0].principal_id
}

# Create additional containers for Medallion architecture
resource "azurerm_storage_container" "bronze_data" {
  name                  = "bronze-data"
  storage_account_name  = azurerm_storage_account.etl_storage.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "silver_data" {
  name                  = "silver-data"
  storage_account_name  = azurerm_storage_account.etl_storage.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "gold_data" {
  name                  = "gold-data"
  storage_account_name  = azurerm_storage_account.etl_storage.name
  container_access_type = "private"
}

# Store Databricks token in Key Vault (will be manually created)
resource "azurerm_key_vault_secret" "databricks_host" {
  name         = "databricks-host"
  value        = "https://${azurerm_databricks_workspace.etl_databricks.workspace_url}"
  key_vault_id = azurerm_key_vault.etl_kv.id

  depends_on = [azurerm_key_vault_access_policy.terraform_policy]
}

# Databricks linked service in Data Factory
resource "azurerm_data_factory_linked_service_azure_databricks" "databricks_linked" {
  name            = "ls_azure_databricks"
  data_factory_id = azurerm_data_factory.etl_adf.id

  description = "Azure Databricks linked service for ETL transformations"

  msi_work_space_resource_id = azurerm_databricks_workspace.etl_databricks.id
  
  existing_cluster_id = var.databricks_cluster_id != "" ? var.databricks_cluster_id : null

  new_cluster_config {
    node_type             = "Standard_DS3_v2"
    cluster_version       = "13.3.x-scala2.12"
    min_number_of_workers = 1
    max_number_of_workers = 2
    
    spark_config = {
      "spark.databricks.delta.preview.enabled" = "true"
    }
    
    spark_env_vars = {
      "PYSPARK_PYTHON" = "/databricks/python3/bin/python3"
    }
  }
}
