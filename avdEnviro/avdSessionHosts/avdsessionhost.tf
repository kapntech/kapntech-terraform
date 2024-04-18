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
      name = "kapntech-avd-sessionhosts"

    }
  }
}

data "terraform_remote_state" "avdInfra" {
  backend = "remote"

  config = {
    organization = "Kapntech"
    workspaces = {
      name = "kapntech-avd-infra"
    }
  }
}

data "terraform_remote_state" "adds" {
  backend = "remote"

  config = {
    organization = "Kapntech"
    workspaces = {
      name = "kapntech-avd"
    }
  }
}

data "terraform_remote_state" "avdplatform" {
  backend = "remote"

  config = {
    organization = "Kapntech"
    workspaces = {
      name = "Kapntech-AVD-Platform"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.avd_subscription_id
}

resource "time_rotating" "avd_registration_expiration" {
  # Must be between 1 hour and 30 days
  rotation_days = 29
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "avd" {
  hostpool_id     = data.terraform_remote_state.avdplatform.outputs.azurerm_virtual_desktop_host_pool_id
  expiration_date = time_rotating.avd_registration_expiration.rotation_rfc3339
}

resource "random_string" "AVD_local_password" {
  count            = var.avd_rdsh_count
  length           = 16
  special          = true
  min_special      = 2
  override_special = "*!@#?"
}

resource "azurerm_resource_group" "avdprod" {
  name     = "rg-${var.avd_resource_group_name_suffix}"
  location = var.avdlocation
}

resource "azurerm_network_interface" "avd_vm_nic" {
  count               = var.avd_rdsh_count
  name                = "nic${count.index + 1}-${var.avd_host_pool_session_host_vm_name_suffix}${count.index + 1}"
  resource_group_name = azurerm_resource_group.avdprod.name
  location            = azurerm_resource_group.avdprod.location

  ip_configuration {
    name                          = "nic${count.index + 1}_config"
    subnet_id                     = data.terraform_remote_state.avdInfra.outputs.avdsubnet_id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [
    azurerm_resource_group.avdprod
  ]
}

resource "azurerm_windows_virtual_machine" "avd_sh" {
  count                 = var.avd_rdsh_count
  name                  = "${var.avd_host_pool_session_host_vm_name_suffix}-${count.index + 1}"
  resource_group_name   = azurerm_resource_group.avdprod.name
  location              = azurerm_resource_group.avdprod.location
  size                  = var.avd_vm_size
  network_interface_ids = ["${azurerm_network_interface.avd_vm_nic.*.id[count.index]}"]
  provision_vm_agent    = true
  admin_username        = var.avd_vm_admin
  admin_password        = var.avd_vm_admin_password

  os_disk {
    name                 = "${lower(var.avd_host_pool_session_host_vm_name_suffix)}-${count.index + 1}"
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
    azurerm_network_interface.avd_vm_nic
  ]
}

resource "azurerm_virtual_machine_extension" "domain_join" {
  count                      = var.avd_rdsh_count
  name                       = "${var.avd_host_pool_session_host_vm_name_suffix}-${count.index + 1}-domainJoin"
  virtual_machine_id         = azurerm_windows_virtual_machine.avd_sh.*.id[count.index]
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
    ignore_changes = [settings, protected_settings]
  }
}

resource "azurerm_virtual_machine_extension" "vmext_dsc" {
  count                      = var.avd_rdsh_count
  name                       = "${var.avd_host_pool_session_host_vm_name_suffix}${count.index + 1}-avd_dsc"
  virtual_machine_id         = azurerm_windows_virtual_machine.avd_sh.*.id[count.index]
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true

  settings = <<-SETTINGS
    {
      "modulesUrl": "${var.avd_register_session_host_modules_url}",
      "configurationFunction": "Configuration.ps1\\AddSessionHost",
      "properties": {
        "hostPoolName": "${data.terraform_remote_state.avdplatform.outputs.azurerm_virtual_desktop_host_pool}",
        "aadJoin": false
      }
    }
    SETTINGS


  protected_settings = <<PROTECTED_SETTINGS
  {
    "properties": {
      "registrationInfoToken": "${azurerm_virtual_desktop_host_pool_registration_info.avd.token}"
    }
  }
PROTECTED_SETTINGS
}