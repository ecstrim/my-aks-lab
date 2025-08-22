# Terraform Backend Configuration for Azure Storage
# 
# This file configures Terraform to store state remotely in Azure Blob Storage
# for better collaboration, state locking, and backup capabilities.
#
# SETUP INSTRUCTIONS:
# 1. Run the setup script: ./scripts/setup-remote-state.sh
# 2. Rename this file to backend.tf: cp backend.tf.example backend.tf
# 3. Update the values below with your actual resource names
# 4. Run: terraform init
#
# IMPORTANT NOTES:
# - The backend configuration cannot use variables or interpolation
# - All values must be hardcoded or provided via CLI arguments
# - State locking is automatically enabled with Azure Storage
# - Backup your state files before making changes

terraform {
  backend "azurerm" {
    resource_group_name   = "rg-aks-terraform-state"
    storage_account_name  = "tfstate61188"
    container_name        = "tfstate"
    key                   = "terraform.tfstate"
  }
}