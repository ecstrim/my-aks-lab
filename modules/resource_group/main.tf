resource "azurerm_resource_group" "main" {
  count = var.create_resource_group ? 1 : 0
  
  name     = var.resource_group_name != "" ? var.resource_group_name : "rg-${var.workload}-${var.environment}-${var.location_short}-${format("%02d", var.instance)}"
  location = var.location

  tags = merge(
    var.tags,
    {
      workload    = var.workload
      environment = var.environment
      managed_by  = "terraform"
    }
  )
}

data "azurerm_resource_group" "existing" {
  count = var.create_resource_group ? 0 : 1
  
  name = var.existing_resource_group_name
}