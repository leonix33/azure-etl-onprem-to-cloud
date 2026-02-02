# Log Analytics Workspace for centralized logging and monitoring
resource "azurerm_log_analytics_workspace" "etl_logs" {
  name                = "log-etl-${random_string.suffix.result}"
  location            = azurerm_resource_group.etl_rg.location
  resource_group_name = azurerm_resource_group.etl_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

# Diagnostic settings for Data Factory
resource "azurerm_monitor_diagnostic_setting" "adf_diagnostics" {
  name                       = "adf-diagnostics"
  target_resource_id         = azurerm_data_factory.etl_adf.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.etl_logs.id

  enabled_log {
    category = "PipelineRuns"
  }

  enabled_log {
    category = "TriggerRuns"
  }

  enabled_log {
    category = "ActivityRuns"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Diagnostic settings for SQL Database
resource "azurerm_monitor_diagnostic_setting" "sql_diagnostics" {
  name                       = "sql-diagnostics"
  target_resource_id         = azurerm_mssql_database.etl_db.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.etl_logs.id

  enabled_log {
    category = "SQLInsights"
  }

  enabled_log {
    category = "Errors"
  }

  enabled_log {
    category = "QueryStoreRuntimeStatistics"
  }

  metric {
    category = "Basic"
    enabled  = true
  }
}

# Diagnostic settings for Storage Account
resource "azurerm_monitor_diagnostic_setting" "storage_diagnostics" {
  name                       = "storage-diagnostics"
  target_resource_id         = azurerm_storage_account.etl_storage.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.etl_logs.id

  metric {
    category = "Transaction"
    enabled  = true
  }

  metric {
    category = "Capacity"
    enabled  = true
  }
}

# Action Group for alert notifications
resource "azurerm_monitor_action_group" "etl_alerts" {
  name                = "etl-alerts-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.etl_rg.name
  short_name          = "ETLAlerts"

  email_receiver {
    name          = "Admin Email"
    email_address = var.alert_email_address
    use_common_alert_schema = true
  }

  tags = var.tags
}

# Alert: Data Factory Pipeline Failure
resource "azurerm_monitor_metric_alert" "pipeline_failure" {
  name                = "adf-pipeline-failures-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.etl_rg.name
  scopes              = [azurerm_data_factory.etl_adf.id]
  description         = "Alert when ADF pipeline fails"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.DataFactory/factories"
    metric_name      = "PipelineFailedRuns"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 0
  }

  action {
    action_group_id = azurerm_monitor_action_group.etl_alerts.id
  }

  tags = var.tags
}

# Alert: SQL Database High DTU Usage
resource "azurerm_monitor_metric_alert" "sql_high_dtu" {
  name                = "sql-high-dtu-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.etl_rg.name
  scopes              = [azurerm_mssql_database.etl_db.id]
  description         = "Alert when SQL Database DTU usage exceeds 80%"
  severity            = 3
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Sql/servers/databases"
    metric_name      = "dtu_consumption_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.etl_alerts.id
  }

  tags = var.tags
}

# Alert: Storage Account High Availability Issues
resource "azurerm_monitor_metric_alert" "storage_availability" {
  name                = "storage-availability-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.etl_rg.name
  scopes              = [azurerm_storage_account.etl_storage.id]
  description         = "Alert when storage availability drops below 99%"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Storage/storageAccounts"
    metric_name      = "Availability"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 99
  }

  action {
    action_group_id = azurerm_monitor_action_group.etl_alerts.id
  }

  tags = var.tags
}

# Cost Management Budget Alert
resource "azurerm_consumption_budget_resource_group" "etl_budget" {
  name              = "etl-monthly-budget"
  resource_group_id = azurerm_resource_group.etl_rg.id

  amount     = 100
  time_grain = "Monthly"

  time_period {
    start_date = "2026-02-01T00:00:00Z"
  }

  notification {
    enabled   = true
    threshold = 80
    operator  = "GreaterThan"

    contact_emails = [
      var.alert_email_address,
    ]
  }

  notification {
    enabled   = true
    threshold = 100
    operator  = "GreaterThan"

    contact_emails = [
      var.alert_email_address,
    ]
  }
}

# Application Insights for advanced monitoring
resource "azurerm_application_insights" "etl_insights" {
  name                = "appi-etl-${random_string.suffix.result}"
  location            = azurerm_resource_group.etl_rg.location
  resource_group_name = azurerm_resource_group.etl_rg.name
  workspace_id        = azurerm_log_analytics_workspace.etl_logs.id
  application_type    = "other"

  tags = var.tags
}
