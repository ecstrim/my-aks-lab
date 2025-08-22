variable "workload" {
  description = "Name of the workload"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "italynorth"
}

variable "instance" {
  description = "Instance number (01-99)"
  type        = number
  default     = 1
  
  validation {
    condition     = var.instance >= 1 && var.instance <= 99
    error_message = "Instance must be between 1 and 99."
  }
}

variable "create_resource_group" {
  description = "Whether to create a new resource group or use an existing one"
  type        = bool
  default     = true
}

variable "resource_group_name" {
  description = "Custom name for the resource group (when creating new). If empty, uses default naming convention."
  type        = string
  default     = ""
}

variable "existing_resource_group_name" {
  description = "Name of the existing resource group (when create_resource_group = false)"
  type        = string
  default     = ""
}

variable "create_vnet" {
  description = "Whether to create a new VNet or use an existing one"
  type        = bool
  default     = true
}

variable "existing_vnet_name" {
  description = "Name of the existing VNet (when create_vnet = false)"
  type        = string
  default     = ""
}

variable "existing_vnet_resource_group_name" {
  description = "Resource group name of the existing VNet (when create_vnet = false)"
  type        = string
  default     = ""
}

variable "existing_subnet_name" {
  description = "Name of the existing subnet (when create_vnet = false)"
  type        = string
  default     = ""
}

variable "create_nsg" {
  description = "Whether to create a network security group (only applies when creating new VNet)"
  type        = bool
  default     = true
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_address_prefix" {
  description = "Address prefix for the AKS subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
  default     = "1.30"
}

variable "node_resource_group_name" {
  description = "Custom name for the AKS managed resource group. If empty, defaults to 'rg-mc-{workload}-{env}-{region}-{instance}'"
  type        = string
  default     = ""
}

variable "node_pool_preset" {
  description = "Node pool VM SKU preset: 'low', 'high', or 'custom'"
  type        = string
  default     = "low"
  
  validation {
    condition     = contains(["low", "high", "custom"], var.node_pool_preset)
    error_message = "Node pool preset must be 'low', 'high', or 'custom'."
  }
}

variable "custom_system_vm_sku" {
  description = "Custom VM SKU for system node pool (used when node_pool_preset = 'custom')"
  type        = string
  default     = "Standard_D4s_v5"
}

variable "custom_user_vm_sku" {
  description = "Custom VM SKU for user node pool (used when node_pool_preset = 'custom')"
  type        = string
  default     = "Standard_D4s_v5"
}

variable "api_server_authorized_ip_ranges" {
  description = "List of authorized IP ranges for API server access. Empty list means public access."
  type        = list(string)
  default     = []
}

variable "network_plugin" {
  description = "Network plugin to use for networking (azure, kubenet)"
  type        = string
  default     = "azure"
  
  validation {
    condition     = contains(["azure", "kubenet"], var.network_plugin)
    error_message = "Network plugin must be 'azure' or 'kubenet'."
  }
}

variable "network_plugin_mode" {
  description = "Network plugin mode when using Azure CNI (overlay or '')"
  type        = string
  default     = "overlay"
  
  validation {
    condition     = var.network_plugin_mode == "" || var.network_plugin_mode == "overlay"
    error_message = "Network plugin mode must be 'overlay' or empty string."
  }
}

variable "network_policy" {
  description = "Network policy to use (azure, calico, or null)"
  type        = string
  default     = "azure"
}

variable "pod_cidr" {
  description = "CIDR for pod IPs when using kubenet or Azure CNI overlay"
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "CIDR for service IPs"
  type        = string
  default     = "10.245.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for DNS service (must be within service_cidr)"
  type        = string
  default     = "10.245.0.10"
}

variable "outbound_type" {
  description = "Outbound routing method (loadBalancer, userDefinedRouting, managedNATGateway)"
  type        = string
  default     = "loadBalancer"
  
  validation {
    condition     = contains(["loadBalancer", "userDefinedRouting", "managedNATGateway"], var.outbound_type)
    error_message = "Outbound type must be 'loadBalancer', 'userDefinedRouting', or 'managedNATGateway'."
  }
}

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for node pools"
  type        = bool
  default     = true
}

variable "system_node_count" {
  description = "Initial number of nodes in system pool"
  type        = number
  default     = 1
}

variable "system_min_count" {
  description = "Minimum number of nodes in system pool (when auto-scaling enabled)"
  type        = number
  default     = 1
}

variable "system_max_count" {
  description = "Maximum number of nodes in system pool (when auto-scaling enabled)"
  type        = number
  default     = 3
}

variable "system_os_disk_size_gb" {
  description = "OS disk size in GB for system pool nodes"
  type        = number
  default     = 128
}

variable "system_os_disk_type" {
  description = "OS disk type for system pool nodes (Managed, Ephemeral)"
  type        = string
  default     = "Managed"
  
  validation {
    condition     = contains(["Managed", "Ephemeral"], var.system_os_disk_type)
    error_message = "OS disk type must be 'Managed' or 'Ephemeral'."
  }
}

variable "user_node_count" {
  description = "Initial number of nodes in user pool"
  type        = number
  default     = 1
}

variable "user_min_count" {
  description = "Minimum number of nodes in user pool (when auto-scaling enabled)"
  type        = number
  default     = 1
}

variable "user_max_count" {
  description = "Maximum number of nodes in user pool (when auto-scaling enabled)"
  type        = number
  default     = 5
}

variable "user_os_disk_size_gb" {
  description = "OS disk size in GB for user pool nodes"
  type        = number
  default     = 128
}

variable "user_os_disk_type" {
  description = "OS disk type for user pool nodes (Managed, Ephemeral)"
  type        = string
  default     = "Managed"
  
  validation {
    condition     = contains(["Managed", "Ephemeral"], var.user_os_disk_type)
    error_message = "OS disk type must be 'Managed' or 'Ephemeral'."
  }
}

variable "user_node_pool_priority" {
  description = "Priority for user node pool (Regular or Spot)"
  type        = string
  default     = "Regular"
  
  validation {
    condition     = contains(["Regular", "Spot"], var.user_node_pool_priority)
    error_message = "User node pool priority must be 'Regular' or 'Spot'."
  }
}

variable "user_node_pool_eviction_policy" {
  description = "Eviction policy for Spot user node pool (Delete or Deallocate)"
  type        = string
  default     = "Delete"
  
  validation {
    condition     = contains(["Delete", "Deallocate"], var.user_node_pool_eviction_policy)
    error_message = "Eviction policy must be 'Delete' or 'Deallocate'."
  }
}

variable "user_node_pool_spot_max_price" {
  description = "Maximum price for Spot instances (-1 for market price)"
  type        = number
  default     = -1
}

variable "azure_rbac_enabled" {
  description = "Enable Azure RBAC for Kubernetes authorization"
  type        = bool
  default     = true
}

variable "admin_group_object_ids" {
  description = "Azure AD group object IDs for cluster admin access"
  type        = list(string)
  default     = []
}

variable "local_account_disabled" {
  description = "Disable local accounts on the cluster"
  type        = bool
  default     = true
}

variable "auto_scaler_profile" {
  description = "Auto-scaler profile configuration"
  type = object({
    balance_similar_node_groups      = bool
    max_graceful_termination_sec     = number
    scale_down_delay_after_add       = string
    scale_down_delay_after_delete    = string
    scale_down_delay_after_failure   = string
    scan_interval                    = string
    scale_down_unneeded              = string
    scale_down_unready               = string
    scale_down_utilization_threshold = number
  })
  default = {
    balance_similar_node_groups      = true
    max_graceful_termination_sec     = 600
    scale_down_delay_after_add       = "10m"
    scale_down_delay_after_delete    = "10s"
    scale_down_delay_after_failure   = "3m"
    scan_interval                    = "10s"
    scale_down_unneeded              = "10m"
    scale_down_unready               = "20m"
    scale_down_utilization_threshold = 0.5
  }
}

# =============================================================================
# AUTHENTICATION VARIABLES
# =============================================================================

variable "client_id" {
  description = "Azure Service Principal Client ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "client_secret" {
  description = "Azure Service Principal Client Secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure AD Tenant ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}