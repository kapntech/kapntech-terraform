output "location" {
  description = "The Azure Region"
  value       = azurerm_resource_group.avdprod.location
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
