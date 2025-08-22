terraform {
  required_version = ">= 1.3.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85"
    }
  }
}

provider "azurerm" {
  # Service Principal Authentication
  # These can be set via environment variables (ARM_CLIENT_ID, etc.) 
  # or passed as variables from secrets.tfvars
  client_id       = var.client_id != "" ? var.client_id : null
  client_secret   = var.client_secret != "" ? var.client_secret : null
  tenant_id       = var.tenant_id != "" ? var.tenant_id : null
  subscription_id = var.subscription_id != "" ? var.subscription_id : null
  
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

locals {
  location_short_map = {
    "eastus"         = "eus"
    "eastus2"        = "eu2"
    "westus"         = "wus"
    "westus2"        = "wu2"
    "centralus"      = "cus"
    "northeurope"    = "neu"
    "westeurope"     = "weu"
    "uksouth"        = "uks"
    "ukwest"         = "ukw"
    "italynorth"     = "itn"
    "southeastasia"  = "sea"
    "eastasia"       = "eas"
    "japaneast"      = "jpe"
    "japanwest"      = "jpw"
    "australiaeast"  = "aue"
    "canadacentral"  = "cac"
    "canadaeast"     = "cae"
  }
  
  location_short = lookup(local.location_short_map, var.location, substr(var.location, 0, 3))
}

module "resource_group" {
  source = "./modules/resource_group"
  
  workload                      = var.workload
  environment                   = var.environment
  location                      = var.location
  location_short                = local.location_short
  instance                      = var.instance
  create_resource_group         = var.create_resource_group
  resource_group_name           = var.resource_group_name
  existing_resource_group_name  = var.existing_resource_group_name
  tags                          = var.tags
}

module "network" {
  source = "./modules/network"
  
  workload                           = var.workload
  environment                        = var.environment
  location                           = var.location
  location_short                     = local.location_short
  instance                           = var.instance
  resource_group_name                = module.resource_group.name
  create_vnet                        = var.create_vnet
  existing_vnet_name                 = var.existing_vnet_name
  existing_vnet_resource_group_name  = var.existing_vnet_resource_group_name
  existing_subnet_name               = var.existing_subnet_name
  create_nsg                         = var.create_nsg
  vnet_address_space                 = var.vnet_address_space
  aks_subnet_address_prefix          = var.aks_subnet_address_prefix
  tags                               = var.tags
}

module "aks" {
  source = "./modules/aks"
  
  workload                         = var.workload
  environment                      = var.environment
  location                         = var.location
  location_short                   = local.location_short
  instance                         = var.instance
  resource_group_name              = module.resource_group.name
  subnet_id                        = module.network.aks_subnet_id
  kubernetes_version               = var.kubernetes_version
  node_resource_group_name         = var.node_resource_group_name
  node_pool_preset                 = var.node_pool_preset
  custom_system_vm_sku             = var.custom_system_vm_sku
  custom_user_vm_sku               = var.custom_user_vm_sku
  api_server_authorized_ip_ranges  = var.api_server_authorized_ip_ranges
  network_plugin                   = var.network_plugin
  network_plugin_mode              = var.network_plugin_mode
  network_policy                   = var.network_policy
  pod_cidr                         = var.pod_cidr
  service_cidr                     = var.service_cidr
  dns_service_ip                   = var.dns_service_ip
  outbound_type                    = var.outbound_type
  enable_auto_scaling              = var.enable_auto_scaling
  system_node_count                = var.system_node_count
  system_min_count                 = var.system_min_count
  system_max_count                 = var.system_max_count
  system_os_disk_size_gb           = var.system_os_disk_size_gb
  system_os_disk_type              = var.system_os_disk_type
  user_node_count                  = var.user_node_count
  user_min_count                   = var.user_min_count
  user_max_count                   = var.user_max_count
  user_os_disk_size_gb             = var.user_os_disk_size_gb
  user_os_disk_type                = var.user_os_disk_type
  user_node_pool_priority          = var.user_node_pool_priority
  user_node_pool_eviction_policy   = var.user_node_pool_eviction_policy
  user_node_pool_spot_max_price    = var.user_node_pool_spot_max_price
  azure_rbac_enabled               = var.azure_rbac_enabled
  admin_group_object_ids           = var.admin_group_object_ids
  local_account_disabled           = var.local_account_disabled
  auto_scaler_profile              = var.auto_scaler_profile
  tags                             = var.tags
}