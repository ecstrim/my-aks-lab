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
}

variable "location_short" {
  description = "Short form of Azure region (e.g., itn for italynorth)"
  type        = string
}

variable "instance" {
  description = "Instance number (01-99)"
  type        = number
  default     = 1
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
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

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}