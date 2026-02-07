# Azure AI Search for RAG
resource "azurerm_search_service" "etl_search" {
  name                = "search-etl-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.etl_rg.name
  location            = azurerm_resource_group.etl_rg.location

  sku                 = var.search_sku
  replica_count       = var.search_replica_count
  partition_count     = var.search_partition_count

  tags = var.tags
}
