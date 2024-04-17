terraform {
  required_version = ">= 1.1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.91.0"
    }
  }
  cloud {
    organization = "Kapntech"
    workspaces {
      name = "kapntech-avd"

    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.adds_subscription_id
}
# Create a resource group
resource "azurerm_resource_group" "addsprod" {
  name     = "rg-${var.adds_resource_group_name_suffix}"
  location = var.addslocation
}

# Create a virtual network
resource "azurerm_virtual_network" "vnetadds" {
  name                = "vnet-${var.adds_vnet_name_suffix}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.addsprod.location
  resource_group_name = azurerm_resource_group.addsprod.name
}

# Create a subnet
resource "azurerm_subnet" "addssubnet" {
  name                 = "snet-${var.adds_subnet_name_suffix}"
  resource_group_name  = azurerm_resource_group.addsprod.name
  virtual_network_name = azurerm_virtual_network.vnetadds.name
  address_prefixes     = var.adds_subnet_address_prefixes
}

resource "azurerm_public_ip" "dcpip" {
  count               = var.adds_dc_count
  name                = "pip-${var.adds_dc_vm_name_suffix}${count.index + 1}"
  location            = azurerm_resource_group.addsprod.location
  resource_group_name = azurerm_resource_group.addsprod.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_security_group" "addsvnetnsg" {
  name                = "nsg-${var.adds_vnet_name_suffix}"
  location            = azurerm_resource_group.addsprod.location
  resource_group_name = azurerm_resource_group.addsprod.name

  security_rule {
    name                       = "RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "adds_vnet_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.addssubnet.id
  network_security_group_id = azurerm_network_security_group.addsvnetnsg.id
}

# Create a network interface
resource "azurerm_network_interface" "nicadds" {
  count               = var.adds_dc_count
  name                = "nic${count.index + 1}-${var.adds_dc_vm_name_suffix}"
  location            = azurerm_resource_group.addsprod.location
  resource_group_name = azurerm_resource_group.addsprod.name

  ip_configuration {
    name                          = "nic${count.index + 1}_config"
    subnet_id                     = azurerm_subnet.addssubnet.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [
    azurerm_resource_group.addsprod
  ]
}

# Create a virtual machine
resource "azurerm_windows_virtual_machine" "dcvm" {
  count               = var.adds_dc_count
  name                = "vm-${var.adds_dc_vm_name_suffix}${count.index + 1}"
  location            = azurerm_resource_group.addsprod.location
  resource_group_name = azurerm_resource_group.addsprod.name
  network_interface_ids = [
    "${azurerm_network_interface.nicadds.*.id[count.index]}"
  ]
  size            = "Standard_DS2_v2"
  priority        = "Spot"
  eviction_policy = "Deallocate"
  admin_username  = var.dc_vm_admin
  admin_password  = var.dc_vm_admin_password

  source_image_reference {
    publisher = var.dc_vm_publisher
    offer     = var.dc_vm_offer
    sku       = var.dc_vm_sku
    version   = var.dc_vm_version
  }

  os_disk {
    name                 = "osdisk-${lower(var.adds_dc_vm_name_suffix)}${count.index + 1}"
    caching              = var.dc_vm_os_disk_caching
    storage_account_type = var.dc_vm_os_disk_storage_account_type
  }
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "devtestshutdown" {
  count              = var.adds_dc_count
  virtual_machine_id = azurerm_windows_virtual_machine.dcvm.*.id[count.index]
  location           = azurerm_resource_group.addsprod.location
  enabled            = true

  daily_recurrence_time = var.dc_vm_autoshutdown_time
  timezone              = var.dc_vm_autoshutdown_time_zone

  notification_settings {
    enabled = var.dc_vm_autoshutdown_notify
  }

}
