terraform {
  required_version = ">= 1.1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.91.0"
    }
    azuread = {
      source = "hashicorp/azuread"
    }
  }
  cloud {
    organization = "Kapntech"
    workspaces {
      name = "kapntech-avd-platform"

    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.avd_subscription_id
}

resource "azurerm_resource_group" "avdprod" {
  name     = "rg-${var.avd_resource_group_name_suffix}"
  location = var.avdlocation
  provider = azurerm
}

resource "azurerm_virtual_desktop_workspace" "avd" {
  name                = "vdws-${var.avd_workspace_name_suffix}"
  location            = azurerm_resource_group.avdprod.location
  resource_group_name = azurerm_resource_group.avdprod.name
  friendly_name       = var.avd_workspace_friendly_name
  description         = var.avd_workspace_description
  provider            = azurerm
}

resource "azurerm_virtual_desktop_host_pool" "avdhp1" {
  resource_group_name      = azurerm_resource_group.avdprod.name
  location                 = azurerm_resource_group.avdprod.location
  name                     = "vdpool-${var.avd_host_pool_name_suffix}"
  friendly_name            = var.avd_host_pool_friendly_name
  description              = var.avd_host_pool_description
  validate_environment     = var.avd_host_pool_validate_environment
  custom_rdp_properties    = var.avd_host_pool_custom_rdp_properties
  type                     = var.avd_host_pool_type
  maximum_sessions_allowed = var.avd_host_pool_maximum_sessions_allowed
  load_balancer_type       = var.avd_host_pool_load_balancer_type
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "avdreginfo1" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.avdhp1.id
  expiration_date = var.rfc3339
}

resource "azurerm_virtual_desktop_application_group" "avdag1" {
  resource_group_name = azurerm_resource_group.avdprod.name
  location            = azurerm_resource_group.avdprod.location
  name                = "vdag-${var.avd_application_group_name_suffix}"
  host_pool_id        = azurerm_virtual_desktop_host_pool.avdhp1.id
  type                = var.avd_application_group_type
  friendly_name       = var.avd_application_group_friendly_name
  description         = var.avd_application_group_description
  depends_on          = [azurerm_virtual_desktop_host_pool.avdhp1, azurerm_virtual_desktop_workspace.avd]
  provider            = azurerm
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "avdappgroupassoc1" {
  workspace_id         = azurerm_virtual_desktop_workspace.avd.id
  application_group_id = azurerm_virtual_desktop_application_group.avdag1.id
  provider             = azurerm
}
