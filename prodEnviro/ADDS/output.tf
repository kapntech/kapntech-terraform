output "adds_resource_group" {
  value = azurerm_resource_group.addsprod.name
}

output "vnetadds_id" {
  value = azurerm_virtual_network.vnetadds.id
}

output "peerADDStoAVD" {
  value = azurerm_virtual_network_peering.peerADDStoAVD.id
}