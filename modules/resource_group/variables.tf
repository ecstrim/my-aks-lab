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

variable "create_resource_group" {
  description = "Whether to create a new resource group or use an existing one"
  type        = bool
  default     = true
}

variable "resource_group_name" {
  description = "Custom name for the resource group (when creating new)"
  type        = string
  default     = ""
}

variable "existing_resource_group_name" {
  description = "Name of the existing resource group (when create_resource_group = false)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}