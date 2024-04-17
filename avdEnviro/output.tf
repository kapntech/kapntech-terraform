output "location" {
  description = "The Azure Region"
  value       = azurerm_resource_group.avdprod.location
}

output "azurerm_virtual_desktop_host_pool" {
  description = "Name of the Azure Virtual Desktop host pool"
  value       = azurerm_virtual_desktop_host_pool.avdhp1.name
}

output "azurerm_virtual_desktop_application_group" {
  description = "Name of the Azure Virtual Desktop DAG"
  value       = azurerm_virtual_desktop_application_group.avdag1.name
}

output "azurerm_virtual_desktop_workspace" {
  description = "Name of the Azure Virtual Desktop workspace"
  value       = azurerm_virtual_desktop_workspace.avd.name
}

output "AVD_user_groupname" {
  description = "Azure Active Directory Group for AVD users"
  value       = azuread_group.aad_group.display_name
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
