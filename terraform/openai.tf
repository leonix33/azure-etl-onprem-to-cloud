# Azure OpenAI for RAG
resource "azurerm_cognitive_account" "etl_openai" {
  name                = "openai-etl-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.etl_rg.name
  location            = azurerm_resource_group.etl_rg.location

  kind                = "OpenAI"
  sku_name            = var.openai_sku

  public_network_access_enabled = true

  tags = var.tags
}
