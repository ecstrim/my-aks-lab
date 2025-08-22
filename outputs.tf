output "resource_group_name" {
  description = "The name of the resource group"
  value       = module.resource_group.name
}

output "resource_group_id" {
  description = "The ID of the resource group"
  value       = module.resource_group.id
}

output "vnet_id" {
  description = "The ID of the virtual network"
  value       = module.network.vnet_id
}

output "vnet_name" {
  description = "The name of the virtual network"
  value       = module.network.vnet_name
}

output "aks_subnet_id" {
  description = "The ID of the AKS subnet"
  value       = module.network.aks_subnet_id
}

output "cluster_id" {
  description = "The ID of the AKS cluster"
  value       = module.aks.cluster_id
}

output "cluster_name" {
  description = "The name of the AKS cluster"
  value       = module.aks.cluster_name
}

output "cluster_fqdn" {
  description = "The FQDN of the AKS cluster"
  value       = module.aks.cluster_fqdn
}

output "cluster_endpoint" {
  description = "The endpoint for the AKS cluster"
  value       = module.aks.cluster_endpoint
  sensitive   = true
}

output "kube_config" {
  description = "Raw kubeconfig for the AKS cluster"
  value       = module.aks.kube_config
  sensitive   = true
}

output "kube_config_command" {
  description = "Azure CLI command to get credentials for the cluster"
  value       = "az aks get-credentials --resource-group ${module.resource_group.name} --name ${module.aks.cluster_name}"
}

output "identity_principal_id" {
  description = "The principal ID of the system assigned identity"
  value       = module.aks.identity_principal_id
}

output "node_resource_group" {
  description = "The name of the auto-created resource group for AKS nodes"
  value       = module.aks.node_resource_group
}

output "oidc_issuer_url" {
  description = "The OIDC issuer URL for workload identity"
  value       = module.aks.oidc_issuer_url
}

output "vnet_resource_group_name" {
  description = "The resource group name of the virtual network"
  value       = module.network.vnet_resource_group_name
}

output "deployment_info" {
  description = "Information about the deployment configuration"
  value = {
    resource_group_created = var.create_resource_group
    vnet_created          = var.create_vnet
    nsg_created           = var.create_nsg && var.create_vnet
    resource_group_name   = module.resource_group.name
    vnet_name            = module.network.vnet_name
    vnet_resource_group  = module.network.vnet_resource_group_name
    subnet_name          = module.network.aks_subnet_name
    node_resource_group  = module.aks.node_resource_group
  }
}