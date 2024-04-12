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
  subscription_id = "var.subscription_id"
}

locals {
  current_time           = timestamp()
  tomorrow               = timeadd(local.current_time, "var.avd_host_pool_registration_expiration_date_length")
}

resource "azurerm_resource_group" "avdprod" {
  name     = "rg-${var.avd_resource_group_name_suffix}"
  location = "var.location"
  provider = azurerm
}

resource "azure_virtual_desktop_workspace" "avd" {
  name                = "vdws-${var.avd_workspace_name_suffix}"
  location            = azurerm_resource_group.avdprod.location
  resource_group_name = azurerm_resource_group.avdprod.name
  friendly_name       = "var.avd_workspace_friendly_name"
  description         = "var.avd_workspace_description"
  provider            = azurerm
}

resource "azurerm_virtual_desktop_host_pool" "avdhp1" {
  resource_group_name = azurerm_resource_group.avdprod.name
  location = azurerm_resource_group.avdprod.location
  name = "vdpool-${var.avd_host_pool_name_suffix}"
  friendly_name = "var.avd_host_pool_friendly_name"
  validate_environment = "var.avd_host_pool_validate_environment"
  type = "var.avd_host_pool_type"
  maximum_sessions_allowed = "var.avd_host_pool_maximum_sessions_allowed"
  load_balancer_type = "var.avd_host_pool_load_balancer_type"
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "avdreginfo1" {
  hostpool_id = azurerm_virtual_desktop_host_pool.avdhp1.id
  expiration_date = "local.tomorrow"
}

resource "azurerm_virtual_desktop_application_group" "avdag1" {
  resource_group_name = azurerm_resource_group.avdprod.name
  location = azurerm_resource_group.avdprod.location
  name = "vdag-${var.avd_application_group_name_suffix}"
  friendly_name = "var.avd_application_group_friendly_name"
  description = "var.avd_application_group_description"
  host_pool_id = azurerm_virtual_desktop_host_pool.avdhp1.id
  provider = azurerm
  type = "var.avd_application_group_type"
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "avdappgroupassoc1" {
  workspace_id = azure_virtual_desktop_workspace.avd.id
  application_group_id = azurerm_virtual_desktop_application_group.avdag1.id
  provider = azurerm
  
}

resource "azurerm_virtual_network" "vnetavd" {
  name                = "vnet-${var.avd_vnet_name_suffix}"
  location            = azurerm_resource_group.avdprod.location
  resource_group_name = azurerm_resource_group.avdprod.name
  address_space       = ["10.0.0.0/16"]
  provider            = azurerm
}

resource "azurerm_subnet" "avdsubnet" {
  name                 = "snet-${var.avd_subnet_name_suffix}"
  resource_group_name  = azurerm_resource_group.avdprod.name
  virtual_network_name = azurerm_virtual_network.vnetavd.name
  address_prefixes     = "var.avd_subnet_address_prefixes"
  provider             = azurerm
}

resource "azurerm_windows_virtual_machine" "avdwin" {
  name                            = "vm-${var.avd_host_pool_session_host_vm_name_suffix}"
  resource_group_name             = azurerm_resource_group.avdprod.name
  location                        = azurerm_resource_group.avdprod.location
  size                            = "var.avd_host_pool_session_host_vm_size"
  priority                        = "var.vm_priority"
  eviction_policy                 = "var.vm_eviction_policy"
  admin_username                  = "var.vm_admin_username"
  admin_password                  = "var.vm_admin_password"
  network_interface_ids = [
    azurerm_network_interface.nicavd1.id,
  ]

  os_disk {
    caching              = "var.os_disk_caching"
    storage_account_type = "var.os_disk_storage_account_type"
  }

  source_image_reference {
    publisher = "var.vm_publisher"
    offer     = "var.vm_offer"
    sku       = "var.vm_sku"
    version   = "var.vm_version"
  }

  tags = {
    Enviro            = "PROD"
    environment       = "AVD"
  }
}

resource "azurerm_network_interface" "nicavd1" {
  name                = "nic${count.index}-azure_rm_virtual_machine.avdwin"
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
