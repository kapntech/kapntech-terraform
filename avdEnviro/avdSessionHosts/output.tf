output "location" {
  description = "The Azure Region"
  value       = azurerm_resource_group.avdprod.location
}

output "session_host_count" {
  description = "The number of VMs created"
  value       = var.avd_rdsh_count
}
