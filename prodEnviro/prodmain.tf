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
    Enviro            = "PROD"
    environment       = "dev"
    ssScheduleEnabled = "true"
    ssScheduleUse     = "WeekendsIST"
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
    Enviro            = "PROD"
    environment       = "staging"
    ssScheduleEnabled = "true"
    ssScheduleUse     = "WeekendsIST"
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
  storage_account_name  = azurerm_storage_account.storaccount1.name
  container_access_type = "private"
}

resource "azurerm_automation_account" "automationacct1" {
  name                = "autoss-runbook-aa"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Basic"
}

data "local_file" "runbookpsinfo" {
  filename = "${path.module}/autoss-getinfo.ps1"
}

data "local_file" "runbookpsstart" {
  filename = "${path.module}/autoss-start.ps1"
}

data "local_file" "runbookpsstop" {
  filename = "${path.module}/autoss-stop.ps1"
}

resource "azurerm_automation_runbook" "runbookpsinfo" {
  name                    = "autoss-getinfo"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.automationacct1.name
  runbook_type            = "PowerShell72"
  log_verbose             = "false"
  log_progress            = "true"

  content = data.local_file.runbookpsinfo.content
}

resource "azurerm_automation_runbook" "runbookpsstart" {
  name                    = "autoss-start"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.automationacct1.name
  runbook_type            = "PowerShell72"
  log_verbose             = "false"
  log_progress            = "true"

  content = data.local_file.runbookpsstart.content
}

resource "azurerm_automation_runbook" "runbookpsstop" {
  name                    = "autoss-stop"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.automationacct1.name
  runbook_type            = "PowerShell72"
  log_verbose             = "false"
  log_progress            = "true"

  content = data.local_file.runbookpsstop.content
}
