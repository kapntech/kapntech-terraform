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
  subscription_id = "cda608ef-aa8d-4a29-be84-dfa63fde334d"
}

resource "azurerm_resource_group" "avdprod" {
  name     = "avd-rg"
  location = "southcentralus"
  provider = azurerm
}

resource "azure_virtual_desktop_workspace" "avd" {
  name                = "avd-remoteapps-workspace"
  location            = azurerm_resource_group.avdprod.location
  resource_group_name = azurerm_resource_group.avdprod.name
  friendly_name       = "AVD RemoteApps Workspace"
  description         = "AVD RemoteApps Workspace"
  provider            = azurerm
}

resource "azurerm_virtual_desktop_host_pool" "avdhp1" {
  resource_group_name = azurerm_resource_group.avdprod.name
  location = azurerm_resource_group.avdprod.location
  name = "avd-remoteapps-hostpool"
  friendly_name = "AVD RemoteApps Hostpool"
  validate_environment = false
  type = "Pooled"
  maximum_sessions_allowed = "3"
  load_balancer_type = "DepthFirst"
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "avdreginfo1" {
  hostpool_id = azurerm_virtual_desktop_host_pool.avdhp1.id
  expiration_date = "2024-03-01T23:40:52Z"
}

resource "azurerm_virtual_desktop_application_group" "avdag1" {
  resource_group_name = azurerm_resource_group.avdprod.name
  location = azurerm_resource_group.avdprod.location
  name = "avd-remoteapps-appgroup"
  friendly_name = "AVD RemoteApps Application Group"
  description = "AVD RemoteApps Application Group"
  host_pool_id = azurerm_virtual_desktop_host_pool.avdhp1.id
  provider = azurerm
  type = "RemoteApp"
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "avdappgroupassoc1" {
  workspace_id = azure_virtual_desktop_workspace.avd.id
  application_group_id = azurerm_virtual_desktop_application_group.avdag1.id
  provider = azurerm
  
}

resource "azurerm_virtual_network" "vnetavd" {
  name                = "avd-vnet"
  location            = azurerm_resource_group.avdprod.location
  resource_group_name = azurerm_resource_group.avdprod.name
  address_space       = ["10.0.0.0/16"]
  provider            = azurerm
}

resource "azurerm_subnet" "avdsubnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.avdprod.name
  virtual_network_name = azurerm_virtual_network.vnetavd.name
  address_prefixes     = ["10.0.1.0/24"]
  provider             = azurerm
}

resource "azurerm_network_interface" "nicavd1" {
  name                = "windows-nic2"
  location            = azurerm_resource_group.avdprod.location
  resource_group_name = azurerm_resource_group.avdprod.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.avdsubnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    Enviro = "PROD"
  }
}

resource "azurerm_windows_virtual_machine" "avdwin" {
  name                            = "avdwin-vm"
  resource_group_name             = azurerm_resource_group.avdprod.name
  location                        = azurerm_resource_group.avdprod.location
  size                            = "Standard_DS1_v2"
  priority                        = "Spot"
  eviction_policy                 = "Deallocate"
  admin_username                  = "azadmin"
  admin_password                  = "Radmin@1q2w#E$R"
  network_interface_ids = [
    azurerm_network_interface.nicavd1.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "20h2-evd"
    version   = "latest"
  }

  tags = {
    Enviro            = "PROD"
    environment       = "prod"
    ssScheduleEnabled = "true"
    ssScheduleUse     = "WeekendsIST"
  }
}


resource "azurerm_dev_test_global_vm_shutdown_schedule" "devtestshutdownprod" {
  virtual_machine_id = azurerm_windows_virtual_machine.avdwin.id
  location           = azurerm_resource_group.avdprod.location
  enabled            = true

  daily_recurrence_time = "1700"
  timezone              = "Central Standard Time"

  notification_settings {
    enabled = false
  }

}
