# Random password for SQL Server
resource "random_password" "sql_password" {
  length  = 16
  special = true
}

# Azure SQL Server
resource "azurerm_mssql_server" "etl_sql" {
  name                         = "sql-etl-${random_string.suffix.result}"
  resource_group_name          = azurerm_resource_group.etl_rg.name
  location                     = azurerm_resource_group.etl_rg.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = random_password.sql_password.result

  azuread_administrator {
    login_username = data.azurerm_client_config.current.object_id
    object_id      = data.azurerm_client_config.current.object_id
  }

  tags = var.tags
}

# Azure SQL Database
resource "azurerm_mssql_database" "etl_db" {
  name           = "db-etl-${var.environment}"
  server_id      = azurerm_mssql_server.etl_sql.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"

  sku_name       = "Basic"
  zone_redundant = false

  tags = var.tags
}

# Firewall rule to allow Azure services
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.etl_sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Firewall rule for your IP (optional)
resource "azurerm_mssql_firewall_rule" "allow_client_ip" {
  count            = length(var.allowed_ip_addresses)
  name             = "AllowClientIP-${count.index}"
  server_id        = azurerm_mssql_server.etl_sql.id
  start_ip_address = split("/", var.allowed_ip_addresses[count.index])[0]
  end_ip_address   = split("/", var.allowed_ip_addresses[count.index])[0]
}

# Linked Service - Azure SQL Database
resource "azurerm_data_factory_linked_service_azure_sql_database" "sql_linked" {
  name            = "ls_azure_sql_database"
  data_factory_id = azurerm_data_factory.etl_adf.id

  key_vault_connection_string {
    linked_service_name = azurerm_data_factory_linked_service_key_vault.kv_linked.name
    secret_name         = azurerm_key_vault_secret.sql_connection_string.name
  }
}
