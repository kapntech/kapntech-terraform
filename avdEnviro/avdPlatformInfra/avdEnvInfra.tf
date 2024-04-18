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
      name = "kapntech-avd-infra"

    }
  }
}

data "terraform_remote_state" "avdADDS" {
  backend = "remote"

  config = {
    organization = "Kapntech"
    workspaces = {
      name = "kapntech-avd"
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

resource "azurerm_virtual_network" "vnetavd" {
  name                = "vnet-${var.avd_vnet_name_suffix}"
  address_space       = ["172.0.0.0/16"]
  location            = azurerm_resource_group.avdprod.location
  resource_group_name = azurerm_resource_group.avdprod.name
}

resource "azurerm_virtual_network_peering" "peerAVDtoADDS" {
  name                      = "peer-${var.avd_vnet_name_suffix}-to-${var.avd_remote_vnet_peer_name_suffix}"
  resource_group_name       = azurerm_resource_group.avdprod.name
  virtual_network_name      = azurerm_virtual_network.vnetavd.name
  remote_virtual_network_id = "${data.terraform_remote_state.avdADDS.outputs.vnetadds_id}"
}

# Create a subnet
resource "azurerm_subnet" "avdsubnet" {
  name                 = "snet-${var.avd_subnet_name_suffix}"
  resource_group_name  = azurerm_resource_group.avdprod.name
  virtual_network_name = azurerm_virtual_network.vnetavd.name
  address_prefixes     = var.avd_subnet_address_prefixes
}

resource "azurerm_network_security_group" "avdvnetnsg" {
  name                = "nsg-${var.avd_vnet_name_suffix}"
  location            = azurerm_resource_group.avdprod.location
  resource_group_name = azurerm_resource_group.avdprod.name
  security_rule {
    name                       = "Allow-Domain-IN"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "Allow-Domain-OUT"
    priority                   = 1000
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "10.0.0.0/16"
  }
  security_rule {
    name                       = "Allow-AVD-OUT"
    priority                   = 1010
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "WindowsVirtualDesktop"
  }
  security_rule {
    name                       = "Allow-AzureCloud-OUT"
    priority                   = 1020
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AzureCloud"
  }
  security_rule {
    name                       = "Allow-AzureKMS-OUT"
    priority                   = 1030
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1688"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "23.102.135.246"
  }
}

resource "azurerm_subnet_network_security_group_association" "avd_vnet_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.avdsubnet.id
  network_security_group_id = azurerm_network_security_group.avdvnetnsg.id
}