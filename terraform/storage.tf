# Storage Account for landing data
resource "azurerm_storage_account" "etl_storage" {
  name                     = "stetl${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.etl_rg.name
  location                 = azurerm_resource_group.etl_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true # Enable Data Lake Gen2

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

# Container for raw data (landing zone)
resource "azurerm_storage_container" "raw_data" {
  name                  = "raw-data"
  storage_account_name  = azurerm_storage_account.etl_storage.name
  container_access_type = "private"
}

# Container for processed data
resource "azurerm_storage_container" "processed_data" {
  name                  = "processed-data"
  storage_account_name  = azurerm_storage_account.etl_storage.name
  container_access_type = "private"
}

# Container for archived data
resource "azurerm_storage_container" "archive_data" {
  name                  = "archive-data"
  storage_account_name  = azurerm_storage_account.etl_storage.name
  container_access_type = "private"
}

# File Share for SHIR and VM data exchange
resource "azurerm_storage_share" "shir_share" {
  name                 = "shir-data-share"
  storage_account_name = azurerm_storage_account.etl_storage.name
  quota                = 100 # GB

  metadata = {
    environment = var.environment
  }
}
