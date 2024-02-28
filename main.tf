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
      name = "kapntech-prod"

    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "90da72fd-4e8b-4566-8304-2c234f193ea5"
}

provider "azurerm" {
  features {}
  alias = "subdev"
  subscription_id = "cda608ef-aa8d-4a29-be84-dfa63fde334d"
}

resource "azurerm_resource_group" "rg" {
  name     = "rg"
  location = "southcentralus"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}



resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}



resource "azurerm_network_interface" "nic" {
  name                = "linux-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    Enviro = "PROD"
  }
}

resource "azurerm_network_interface" "nic2" {
  name                = "linux-nic2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    Enviro = "PROD"
  }
}



resource "azurerm_linux_virtual_machine" "linux" {
  name                            = "linux-vm"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = "Standard_DS1_v2"
  priority                        = "Spot"
  eviction_policy                 = "Deallocate"
  admin_username                  = "azadmin"
  admin_password                  = "Radmin@1q2w#E$R"
  disable_password_authentication = "false"
  network_interface_ids = [
    azurerm_network_interface.nic.id,
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
    Enviro = "PROD"
    environment = "dev"
    ssScheduleEnabled = "true"
    ssScheduleUse = "WeekendsIST"
  }
}

resource "azurerm_linux_virtual_machine" "linux2" {
  name                            = "linux-vm2"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = "Standard_DS1_v2"
  priority                        = "Spot"
  eviction_policy                 = "Deallocate"
  admin_username                  = "azadmin"
  admin_password                  = "Radmin@1q2w#E$R"
  disable_password_authentication = "false"
  network_interface_ids = [
    azurerm_network_interface.nic2.id,
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
    Enviro = "PROD"
    environment = "staging"
    ssScheduleEnabled = "true"
    ssScheduleUse = "WeekendsIST"
  }
}



resource "azurerm_dev_test_global_vm_shutdown_schedule" "devtestshutdown" {
  virtual_machine_id = azurerm_linux_virtual_machine.linux.id
  location           = azurerm_resource_group.rg.location
  enabled            = true

  daily_recurrence_time = "1700"
  timezone              = "Central Standard Time"

  notification_settings {
    enabled = false
  }

}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "devtestshutdown2" {
  virtual_machine_id = azurerm_linux_virtual_machine.linux2.id
  location           = azurerm_resource_group.rg.location
  enabled            = true

  daily_recurrence_time = "1700"
  timezone              = "Central Standard Time"

  notification_settings {
    enabled = false
  }

}

resource "azurerm_storage_account" "storaccount1" {
  name                     = "storaccount1ansjhxiu"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "storaccount1cont1" {
  name                  = "csvs"
  storage_account_name = azurerm_storage_account.storaccount1.name
  container_access_type = "private"
}

resource "azurerm_resource_group" "rgdev" {
  name     = "dev-rg"
  location = "southcentralus"
  provider = azurerm.subdev
}

resource "azurerm_virtual_network" "vnetdev" {
  name                = "dev-vnet"
  location            = azurerm_resource_group.rgdev.location
  resource_group_name = azurerm_resource_group.rgdev.name
  address_space       = ["10.0.0.0/16"]
  provider = azurerm.subdev
}

resource "azurerm_subnet" "devsubnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rgdev.name
  virtual_network_name = azurerm_virtual_network.vnetdev.name
  address_prefixes     = ["10.0.1.0/24"]
  provider = azurerm.subdev
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
    Enviro = "DEV"
    environment = "dev"
    ssScheduleEnabled = "true"
    ssScheduleUse = "WeekendsIST"
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
