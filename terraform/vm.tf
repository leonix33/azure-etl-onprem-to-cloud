# Virtual Machine for Self-Hosted Integration Runtime
resource "azurerm_windows_virtual_machine" "shir_vm" {
  name                = "vm-shir-${var.environment}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.etl_rg.name
  location            = azurerm_resource_group.etl_rg.location
  size                = var.vm_size
  admin_username      = var.vm_admin_username
  admin_password      = azurerm_key_vault_secret.vm_admin_password.value

  network_interface_ids = [
    azurerm_network_interface.vm_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = merge(var.tags, {
    Role = "SHIR-Host"
  })

  depends_on = [azurerm_key_vault_secret.vm_admin_password]
}

# Auto-shutdown schedule for cost savings
resource "azurerm_dev_test_global_vm_shutdown_schedule" "shir_vm_shutdown" {
  virtual_machine_id = azurerm_windows_virtual_machine.shir_vm.id
  location           = azurerm_resource_group.etl_rg.location
  enabled            = true

  daily_recurrence_time = "1900" # 7 PM
  timezone              = "Eastern Standard Time"

  notification_settings {
    enabled = false
  }

  tags = var.tags
}

# Custom Script Extension to install prerequisites
resource "azurerm_virtual_machine_extension" "shir_setup" {
  name                 = "install-prerequisites"
  virtual_machine_id   = azurerm_windows_virtual_machine.shir_vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -Command \"New-Item -Path '${var.source_data_path}' -ItemType Directory -Force; Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force\""
  })

  tags = var.tags
}
