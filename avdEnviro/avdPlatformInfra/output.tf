output "location" {
  description = "The Azure Region"
  value       = azurerm_resource_group.avdprod.location
}

output "avd_rg_name" {
  description = "The Azure Region"
  value       = azurerm_resource_group.avdprod.name
}

output "session_host_count" {
  description = "The number of VMs created"
  value       = var.avd_rdsh_count
}

output "dnsservers" {
  description = "Custom DNS Configuration"
  value       = azurerm_virtual_network.vnetavd.dns_servers
}

output "vnetrange" {
  description = "Address range for deployment vnet"
  value       = azurerm_virtual_network.vnetavd.address_space
}

output "vnetavd_id" {
  description = "Address range for deployment vnet"
  value       = azurerm_virtual_network.vnetavd.id
}

output "avdsubnet_id" {
  description = "Address range for deployment vnet"
  value       = azurerm_subnet.avdsubnet.id
}

output "peerAVDtoADDS_id" {
  description = "Address range for deployment vnet"
  value       = azurerm_virtual_network_peering.peerAVDtoADDS.id
}


