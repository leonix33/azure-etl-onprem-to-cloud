# Virtual Machine for Self-Hosted Integration Runtime
resource "azurerm_windows_virtual_machine" "shir_vm" {
  name                = "vm-shir-${random_string.suffix.result}"
  computer_name       = "vmshir"
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

# Custom Script Extension to download and install SHIR
resource "azurerm_virtual_machine_extension" "shir_setup" {
  name                       = "install-shir"
  virtual_machine_id         = azurerm_windows_virtual_machine.shir_vm.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  protected_settings = jsonencode({
    commandToExecute = <<-EOT
      powershell -ExecutionPolicy Bypass -Command "
        # Create data directory
        New-Item -Path '${var.source_data_path}' -ItemType Directory -Force

        # Download SHIR installer
        $installerUrl = 'https://download.microsoft.com/download/E/4/7/E4771905-1079-445B-8BF9-8A1A075D8A10/IntegrationRuntime_5.39.8841.2.msi'
        $installerPath = 'C:\Temp\IntegrationRuntime.msi'
        New-Item -Path 'C:\Temp' -ItemType Directory -Force
        
        Write-Output 'Downloading SHIR installer...'
        Invoke-WebRequest -Uri `$installerUrl -OutFile `$installerPath -UseBasicParsing
        
        # Install SHIR silently
        Write-Output 'Installing SHIR...'
        Start-Process msiexec.exe -ArgumentList '/i', `$installerPath, '/quiet', '/norestart' -Wait
        
        # Wait for installation to complete
        Start-Sleep -Seconds 30
        
        # Register SHIR with Data Factory
        Write-Output 'Registering SHIR with Data Factory...'
        $shirPath = 'C:\Program Files\Microsoft Integration Runtime\5.0\Shared\dmgcmd.exe'
        if (Test-Path `$shirPath) {
          $authKey = '${azurerm_data_factory_integration_runtime_self_hosted.shir.primary_authorization_key}'
          & `$shirPath -RegisterNewNode `$authKey
          Write-Output 'SHIR registration completed'
        } else {
          Write-Output 'SHIR executable not found, registration skipped'
        }
      "
    EOT
  })

  tags = var.tags
}
