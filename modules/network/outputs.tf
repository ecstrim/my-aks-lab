output "vnet_id" {
  description = "The ID of the virtual network"
  value       = var.create_vnet ? azurerm_virtual_network.main[0].id : data.azurerm_virtual_network.existing[0].id
}

output "vnet_name" {
  description = "The name of the virtual network"
  value       = var.create_vnet ? azurerm_virtual_network.main[0].name : data.azurerm_virtual_network.existing[0].name
}

output "aks_subnet_id" {
  description = "The ID of the AKS subnet"
  value       = var.create_vnet ? azurerm_subnet.aks[0].id : data.azurerm_subnet.existing[0].id
}

output "aks_subnet_name" {
  description = "The name of the AKS subnet"
  value       = var.create_vnet ? azurerm_subnet.aks[0].name : data.azurerm_subnet.existing[0].name
}

output "nsg_id" {
  description = "The ID of the network security group (null if not created)"
  value       = var.create_nsg && var.create_vnet ? azurerm_network_security_group.aks[0].id : null
}

output "vnet_resource_group_name" {
  description = "The resource group name of the virtual network"
  value       = var.create_vnet ? var.resource_group_name : var.existing_vnet_resource_group_name
}