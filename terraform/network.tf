# Virtual Network
resource "azurerm_virtual_network" "etl_vnet" {
  name                = "vnet-etl-${var.environment}-${random_string.suffix.result}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.etl_rg.location
  resource_group_name = azurerm_resource_group.etl_rg.name

  tags = var.tags
}

# Subnet for VM
resource "azurerm_subnet" "vm_subnet" {
  name                 = "snet-vm-${var.environment}"
  resource_group_name  = azurerm_resource_group.etl_rg.name
  virtual_network_name = azurerm_virtual_network.etl_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group for VM
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "nsg-shir-vm-${var.environment}"
  location            = azurerm_resource_group.etl_rg.location
  resource_group_name = azurerm_resource_group.etl_rg.name

  # Allow RDP from specific IPs only
  security_rule {
    name                       = "AllowRDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefixes    = length(var.allowed_ip_addresses) > 0 ? var.allowed_ip_addresses : ["0.0.0.0/0"]
    destination_address_prefix = "*"
  }

  # Allow outbound HTTPS for SHIR communication
  security_rule {
    name                       = "AllowHTTPSOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "80"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# Public IP for VM
resource "azurerm_public_ip" "vm_pip" {
  name                = "pip-shir-vm-${var.environment}"
  location            = azurerm_resource_group.etl_rg.location
  resource_group_name = azurerm_resource_group.etl_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# Network Interface for VM
resource "azurerm_network_interface" "vm_nic" {
  name                = "nic-shir-vm-${var.environment}"
  location            = azurerm_resource_group.etl_rg.location
  resource_group_name = azurerm_resource_group.etl_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_pip.id
  }

  tags = var.tags
}

# Associate NSG with NIC
resource "azurerm_network_interface_security_group_association" "vm_nic_nsg" {
  network_interface_id      = azurerm_network_interface.vm_nic.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}
