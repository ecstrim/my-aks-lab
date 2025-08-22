resource "azurerm_virtual_network" "main" {
  count = var.create_vnet ? 1 : 0
  
  name                = "vnet-${var.workload}-${var.environment}-${var.location_short}-${format("%02d", var.instance)}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_address_space]

  tags = merge(
    var.tags,
    {
      workload    = var.workload
      environment = var.environment
      managed_by  = "terraform"
    }
  )
}

data "azurerm_virtual_network" "existing" {
  count = var.create_vnet ? 0 : 1
  
  name                = var.existing_vnet_name
  resource_group_name = var.existing_vnet_resource_group_name
}

resource "azurerm_subnet" "aks" {
  count = var.create_vnet ? 1 : 0
  
  name                 = "snet-aks-${var.workload}-${var.environment}-${var.location_short}-${format("%02d", var.instance)}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = [var.aks_subnet_address_prefix]
}

data "azurerm_subnet" "existing" {
  count = var.create_vnet ? 0 : 1
  
  name                 = var.existing_subnet_name
  virtual_network_name = var.existing_vnet_name
  resource_group_name  = var.existing_vnet_resource_group_name
}

resource "azurerm_network_security_group" "aks" {
  count = var.create_nsg ? 1 : 0
  
  name                = "nsg-aks-${var.workload}-${var.environment}-${var.location_short}-${format("%02d", var.instance)}"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(
    var.tags,
    {
      workload    = var.workload
      environment = var.environment
      managed_by  = "terraform"
    }
  )
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  count = var.create_nsg && var.create_vnet ? 1 : 0
  
  subnet_id                 = azurerm_subnet.aks[0].id
  network_security_group_id = azurerm_network_security_group.aks[0].id
}