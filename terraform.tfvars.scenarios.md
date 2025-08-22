# Terraform Configuration Scenarios

This document provides example configurations for common deployment scenarios.

## Scenario 1: New Deployment (Default)
Create everything from scratch with default naming conventions.

```hcl
# terraform.tfvars
workload    = "myapp"
environment = "dev"
location    = "italynorth"
instance    = 1

# Use defaults - creates new RG, VNet, and all resources
create_resource_group = true
create_vnet          = true

api_server_authorized_ip_ranges = ["YOUR_IP/32"]
admin_group_object_ids = ["YOUR_AAD_GROUP_ID"]
```

## Scenario 2: Use Existing Resource Group
Deploy AKS into an existing resource group but create new networking.

```hcl
# terraform.tfvars
workload    = "myapp"
environment = "prod"
location    = "italynorth"
instance    = 1

# Use existing resource group
create_resource_group        = false
existing_resource_group_name = "rg-existing-myapp-prod-itn-01"

# Create new VNet in the existing RG
create_vnet               = true
vnet_address_space        = "10.1.0.0/16"
aks_subnet_address_prefix = "10.1.1.0/24"

api_server_authorized_ip_ranges = ["YOUR_IP/32"]
admin_group_object_ids = ["YOUR_AAD_GROUP_ID"]
```

## Scenario 3: Use Existing VNet in Same Resource Group
Deploy AKS using existing networking in the same resource group.

```hcl
# terraform.tfvars
workload    = "myapp"
environment = "prod"
location    = "italynorth"
instance    = 1

# Use existing resource group
create_resource_group        = false
existing_resource_group_name = "rg-myapp-prod-itn-01"

# Use existing VNet in the same RG
create_vnet                        = false
existing_vnet_name                 = "vnet-myapp-prod-itn-01"
existing_vnet_resource_group_name  = "rg-myapp-prod-itn-01"  # Same as above
existing_subnet_name               = "snet-aks-myapp-prod-itn-01"

api_server_authorized_ip_ranges = ["YOUR_IP/32"]
admin_group_object_ids = ["YOUR_AAD_GROUP_ID"]
```

## Scenario 4: Use Existing VNet in Different Resource Group
Deploy AKS using existing networking from a different (hub) resource group.

```hcl
# terraform.tfvars
workload    = "myapp"
environment = "prod"
location    = "italynorth"
instance    = 1

# Create new resource group for AKS
create_resource_group = true

# Use existing VNet from hub/network RG
create_vnet                        = false
existing_vnet_name                 = "vnet-hub-prod-itn-01"
existing_vnet_resource_group_name  = "rg-network-hub-prod-itn-01"  # Different RG
existing_subnet_name               = "snet-aks-myapp-prod-itn-01"

api_server_authorized_ip_ranges = ["YOUR_IP/32"]
admin_group_object_ids = ["YOUR_AAD_GROUP_ID"]
```

## Scenario 5: Custom Resource Group and Managed RG Names
Use custom names for both the deployment RG and AKS managed RG.

```hcl
# terraform.tfvars
workload    = "myapp"
environment = "prod"
location    = "italynorth"
instance    = 1

# Create new RG with custom name
create_resource_group = true
resource_group_name  = "rg-myapp-aks-prod-custom"

# Custom AKS managed resource group name
node_resource_group_name = "rg-mc-myapp-aks-prod-custom"

# Create new networking
create_vnet = true

api_server_authorized_ip_ranges = ["YOUR_IP/32"]
admin_group_object_ids = ["YOUR_AAD_GROUP_ID"]
```

## Scenario 6: Hub-Spoke with Existing Everything
Deploy AKS using existing resource group and existing hub VNet.

```hcl
# terraform.tfvars
workload    = "myapp"
environment = "prod"
location    = "italynorth"
instance    = 2  # Second instance

# Use existing spoke resource group
create_resource_group        = false
existing_resource_group_name = "rg-spoke-myapp-prod-itn-01"

# Use existing VNet from hub RG
create_vnet                        = false
existing_vnet_name                 = "vnet-hub-prod-itn-01"
existing_vnet_resource_group_name  = "rg-network-hub-prod-itn-01"
existing_subnet_name               = "snet-aks-spoke-myapp-prod-itn-01"

# Custom AKS managed RG name for organization
node_resource_group_name = "rg-mc-myapp-prod-itn-02"

# High-performance preset for production
node_pool_preset = "high"

api_server_authorized_ip_ranges = ["10.0.0.0/8", "172.16.0.0/16"]
admin_group_object_ids = ["YOUR_AAD_GROUP_ID"]
```

## Key Points

1. **Resource Group Flexibility**: You can create new or use existing resource groups
2. **Network Flexibility**: VNet can be in the same or different resource group
3. **Naming Control**: Custom names for deployment RG and AKS managed RG
4. **Instance Numbers**: Use different instance numbers for multiple deployments
5. **Security**: Always configure `api_server_authorized_ip_ranges` for production

## Required Variables by Scenario

| Scenario | Required Variables |
|----------|-------------------|
| New Everything | `workload`, `environment`, `api_server_authorized_ip_ranges` |
| Existing RG | Above + `existing_resource_group_name` |
| Existing VNet (same RG) | Above + `existing_vnet_name`, `existing_subnet_name` |
| Existing VNet (diff RG) | Above + `existing_vnet_resource_group_name` |
| Custom Names | Any scenario + `resource_group_name`, `node_resource_group_name` |