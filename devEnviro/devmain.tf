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
      name = "kapntech-terraform"

    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "cda608ef-aa8d-4a29-be84-dfa63fde334d"
}

resource "azurerm_resource_group" "rgdev" {
  name     = "dev-rg"
  location = "southcentralus"
  provider = azurerm
}

resource "azurerm_virtual_network" "vnetdev" {
  name                = "dev-vnet"
  location            = azurerm_resource_group.rgdev.location
  resource_group_name = azurerm_resource_group.rgdev.name
  address_space       = ["10.0.0.0/16"]
  provider            = azurerm
}

resource "azurerm_subnet" "devsubnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rgdev.name
  virtual_network_name = azurerm_virtual_network.vnetdev.name
  address_prefixes     = ["10.0.1.0/24"]
  provider             = azurerm
}

resource "azurerm_network_interface" "nicdev1" {
  name                = "linux-nic2"
  location            = azurerm_resource_group.rgdev.location
  resource_group_name = azurerm_resource_group.rgdev.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.devsubnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    Enviro = "DEV"
  }
}

resource "azurerm_linux_virtual_machine" "devlinux" {
  name                            = "devlinux-vm"
  resource_group_name             = azurerm_resource_group.rgdev.name
  location                        = azurerm_resource_group.rgdev.location
  size                            = "Standard_DS1_v2"
  priority                        = "Spot"
  eviction_policy                 = "Deallocate"
  admin_username                  = "azadmin"
  admin_password                  = "Radmin@1q2w#E$R"
  disable_password_authentication = "false"
  network_interface_ids = [
    azurerm_network_interface.nicdev1.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = {
    Enviro            = "DEV"
    environment       = "dev"
    ssScheduleEnabled = "true"
    ssScheduleUse     = "WeekendsIST"
  }
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "devtestshutdowndev" {
  virtual_machine_id = azurerm_linux_virtual_machine.devlinux.id
  location           = azurerm_resource_group.rgdev.location
  enabled            = true

  daily_recurrence_time = "1700"
  timezone              = "Central Standard Time"

  notification_settings {
    enabled = false
  }

}
