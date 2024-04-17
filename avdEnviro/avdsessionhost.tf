terraform {
  required_version = ">= 1.1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.91.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
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
  subscription_id = var.avd_subscription_id
}

locals {
  registration_token = azurerm_virtual_desktop_host_pool_registration_info.registrationinfo.token
}

resource "random_string" "AVD_local_password" {
  count            = var.avd_rdsh_count
  length           = 16
  special          = true
  min_special      = 2
  override_special = "*!@#?"
}

resource "azurerm_network_interface" "nicavd" {
  count               = var.avd_rdsh_count
  name                = "nic${count.index + 1}-${var.avd_host_pool_session_host_vm_name_suffix}${count.index + 1}"
  location            = azurerm_resource_group.avdprod.location
  resource_group_name = azurerm_resource_group.avdprod.name

  ip_configuration {
    name                          = "$nic${count.index + 1}_config"
    subnet_id                     = azurerm_subnet.avdsubnet.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [
    azurerm_resource_group.avdprod
  ]
}

resource "azurerm_windows_virtual_machine" "avdwin" {
  count               = var.avd_rdsh_count
  name                = "vm-${var.avd_host_pool_session_host_vm_name_suffix}${count.index + 1}"
  resource_group_name = azurerm_resource_group.avdprod.name
  location            = azurerm_resource_group.avdprod.location
  size                = var.avd_vm_size

  network_interface_ids = [
    "${azurerm_network_interface.nicavd.*.id[count.index]}"
  ]
  provision_vm_agent = true
  admin_username     = var.avd_vm_admin
  admin_password     = var.avd_vm_admin_password

  os_disk {
    name                 = "osdisk-${lower(var.avd_host_pool_session_host_vm_name_suffix)}-${count.index + 1}"
    caching              = var.avd_vm_os_disk_caching
    storage_account_type = var.avd_vm_os_disk_storage_account_type
  }

  source_image_reference {
    publisher = var.avd_vm_publisher
    offer     = var.avd_vm_offer
    sku       = var.avd_vm_sku
    version   = var.avd_vm_version
  }

  depends_on = [
    azurerm_resource_group.avdprod,
    azurerm_network_interface.nicavd
  ]
}

resource "azurerm_virtual_machine_extension" "domain_join" {
  count                      = var.avd_rdsh_count
  name                       = "vm-${var.avd_host_pool_session_host_vm_name_suffix}${count.index + 1}-domainjoin"
  virtual_machine_id         = azurerm_windows_virtual_machine.avdwin[count.index].id
  publisher                  = "Microsoft.Compute"
  type                       = "JsonADDomainExtension"
  type_handler_version       = "1.3"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
        "Name": "${var.domain_name}",
        "OUPath": "${var.ou_path}",
        "User": "${var.domain_user_upn}@${var.domain_name}",
        "Restart": "true",
        "Options": "3"
    }
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
        "Password": "${var.domain_user_password}"
    }
PROTECTED_SETTINGS

  lifecycle {
    ignore_changes = [
      settings,
      protected_settings
    ]
  }

  depends_on = [
    azurerm_virtual_network_peering.peering.peer1,
    azurerm_virtual_network_peering.peering.peer2,
  ]
}

resource "azurerm_virtual_machine_extension" "vmext_dsc" {
  count                      = var.avd_rdsh_count
  name                       = "vm-${var.avd_host_pool_session_host_vm_name_suffix}${count.index + 1}-avd_dsc"
  virtual_machine_id         = azurerm_windows_virtual_machine.avd_vm.*.id[count.index]
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true

  settings = <<-SETTINGS
    {
      "modulesUrl": "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_09-08-2022.zip",
      "configurationFunction": "Configuration.ps1\\AddSessionHost",
      "properties": {
        "HostPoolName":"${azurerm_virtual_desktop_host_pool.hostpool.name}"
      }
    }
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
  {
    "properties": {
      "registrationInfoToken": "${local.registration_token}"
    }
  }
PROTECTED_SETTINGS

  depends_on = [
    azurerm_virtual_machine_extension.domain_join,
    azurerm_virtual_desktop_host_pool.hostpool
  ]
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
  address_prefixes     = var.avd_subnet_address_prefixes
  provider             = azurerm
}