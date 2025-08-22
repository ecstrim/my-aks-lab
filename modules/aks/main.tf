locals {
  vm_sku_map = {
    low = {
      system = "Standard_B2ms"
      user   = "Standard_B2ms"
    }
    high = {
      system = "Standard_D4s_v5"
      user   = "Standard_D8s_v5"
    }
    custom = {
      system = var.custom_system_vm_sku
      user   = var.custom_user_vm_sku
    }
  }
  
  system_vm_sku = local.vm_sku_map[var.node_pool_preset].system
  user_vm_sku   = local.vm_sku_map[var.node_pool_preset].user
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.workload}-${var.environment}-${var.location_short}-${format("%02d", var.instance)}"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "aks-${var.workload}-${var.environment}-${var.location_short}-${format("%02d", var.instance)}"
  kubernetes_version  = var.kubernetes_version
  node_resource_group = var.node_resource_group_name != "" ? var.node_resource_group_name : "rg-mc-${var.workload}-${var.environment}-${var.location_short}-${format("%02d", var.instance)}"

  api_server_access_profile {
    authorized_ip_ranges = var.api_server_authorized_ip_ranges
  }

  default_node_pool {
    name                = "system"
    node_count          = var.system_node_count
    vm_size             = local.system_vm_sku
    vnet_subnet_id      = var.subnet_id
    enable_auto_scaling = var.enable_auto_scaling
    min_count           = var.enable_auto_scaling ? var.system_min_count : null
    max_count           = var.enable_auto_scaling ? var.system_max_count : null
    os_disk_size_gb     = var.system_os_disk_size_gb
    os_disk_type        = var.system_os_disk_type
    
    node_labels = {
      "nodepool-type" = "system"
      "environment"   = var.environment
      "workload"      = var.workload
    }
    
    only_critical_addons_enabled = true
    
    tags = merge(
      var.tags,
      {
        nodepool    = "system"
        environment = var.environment
      }
    )
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = var.network_plugin
    network_plugin_mode = var.network_plugin == "azure" ? var.network_plugin_mode : null
    network_policy      = var.network_policy
    pod_cidr            = var.network_plugin == "kubenet" || (var.network_plugin == "azure" && var.network_plugin_mode == "overlay") ? var.pod_cidr : null
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    outbound_type       = var.outbound_type
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = var.azure_rbac_enabled
    admin_group_object_ids = var.admin_group_object_ids
  }

  local_account_disabled = var.local_account_disabled

  auto_scaler_profile {
    balance_similar_node_groups      = var.auto_scaler_profile.balance_similar_node_groups
    max_graceful_termination_sec     = var.auto_scaler_profile.max_graceful_termination_sec
    scale_down_delay_after_add       = var.auto_scaler_profile.scale_down_delay_after_add
    scale_down_delay_after_delete    = var.auto_scaler_profile.scale_down_delay_after_delete
    scale_down_delay_after_failure   = var.auto_scaler_profile.scale_down_delay_after_failure
    scan_interval                    = var.auto_scaler_profile.scan_interval
    scale_down_unneeded              = var.auto_scaler_profile.scale_down_unneeded
    scale_down_unready               = var.auto_scaler_profile.scale_down_unready
    scale_down_utilization_threshold = var.auto_scaler_profile.scale_down_utilization_threshold
  }

  tags = merge(
    var.tags,
    {
      workload    = var.workload
      environment = var.environment
      managed_by  = "terraform"
    }
  )
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size              = local.user_vm_sku
  node_count           = var.user_node_count
  vnet_subnet_id       = var.subnet_id
  
  enable_auto_scaling = var.enable_auto_scaling
  min_count          = var.enable_auto_scaling ? var.user_min_count : null
  max_count          = var.enable_auto_scaling ? var.user_max_count : null
  
  os_disk_size_gb = var.user_os_disk_size_gb
  os_disk_type    = var.user_os_disk_type
  
  priority        = var.user_node_pool_priority
  eviction_policy = var.user_node_pool_priority == "Spot" ? var.user_node_pool_eviction_policy : null
  spot_max_price  = var.user_node_pool_priority == "Spot" ? var.user_node_pool_spot_max_price : null
  
  node_labels = merge(
    {
      "nodepool-type" = "user"
      "environment"   = var.environment
      "workload"      = var.workload
    },
    var.user_node_pool_priority == "Spot" ? { "kubernetes.azure.com/scalesetpriority" = "spot" } : {}
  )
  
  node_taints = var.user_node_pool_priority == "Spot" ? ["kubernetes.azure.com/scalesetpriority=spot:NoSchedule"] : []
  
  tags = merge(
    var.tags,
    {
      nodepool    = "user"
      environment = var.environment
    }
  )
}